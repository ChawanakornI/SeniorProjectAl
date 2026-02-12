"""
Integration Tests for Active Learning System.

Tests the full workflow from label collection to model promotion.
Run with: pytest backserver/tests/test_al_integration.py -v
"""

import json
import os
import sys
import tempfile
import shutil
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from backserver import config
from backserver import model_registry
from backserver import training_config
from backserver import labels_pool
from backserver import event_log
from backserver import auto_promote


@pytest.fixture
def temp_al_workspace(tmp_path):
    """Create a temporary AL workspace for testing."""
    # Create directory structure
    workspace = tmp_path / "AL_Back"
    (workspace / "models" / "production").mkdir(parents=True)
    (workspace / "models" / "candidates").mkdir(parents=True)
    (workspace / "models" / "archive").mkdir(parents=True)
    (workspace / "db").mkdir(parents=True)
    (workspace / "config").mkdir(parents=True)

    # Initialize files
    (workspace / "db" / "model_registry.json").write_text(
        '{"models": {}, "current_production": null, "pending_promotion": null}'
    )
    (workspace / "db" / "labels_pool.jsonl").write_text("")
    (workspace / "db" / "event_log.jsonl").write_text("")
    (workspace / "config" / "active_config.json").write_text(
        '{"epochs": 10, "batch_size": 16, "learning_rate": 0.0001, "optimizer": "Adam"}'
    )

    # Patch config paths
    original_workspace = config.AL_WORKSPACE_ROOT
    original_registry = config.AL_MODEL_REGISTRY_FILE
    original_labels = config.AL_LABELS_POOL_FILE
    original_events = config.AL_EVENT_LOG_FILE
    original_config = config.AL_ACTIVE_CONFIG_FILE
    original_candidates = config.AL_CANDIDATES_DIR
    original_archive = config.AL_ARCHIVE_DIR
    original_production = config.AL_PRODUCTION_DIR

    config.AL_WORKSPACE_ROOT = str(workspace)
    config.AL_MODEL_REGISTRY_FILE = str(workspace / "db" / "model_registry.json")
    config.AL_LABELS_POOL_FILE = str(workspace / "db" / "labels_pool.jsonl")
    config.AL_EVENT_LOG_FILE = str(workspace / "db" / "event_log.jsonl")
    config.AL_ACTIVE_CONFIG_FILE = str(workspace / "config" / "active_config.json")
    config.AL_CANDIDATES_DIR = str(workspace / "models" / "candidates")
    config.AL_ARCHIVE_DIR = str(workspace / "models" / "archive")
    config.AL_PRODUCTION_DIR = str(workspace / "models" / "production")

    yield workspace

    # Restore original paths
    config.AL_WORKSPACE_ROOT = original_workspace
    config.AL_MODEL_REGISTRY_FILE = original_registry
    config.AL_LABELS_POOL_FILE = original_labels
    config.AL_EVENT_LOG_FILE = original_events
    config.AL_ACTIVE_CONFIG_FILE = original_config
    config.AL_CANDIDATES_DIR = original_candidates
    config.AL_ARCHIVE_DIR = original_archive
    config.AL_PRODUCTION_DIR = original_production


class TestModelRegistry:
    """Tests for model_registry module."""

    def test_generate_version_id(self, temp_al_workspace):
        """Version IDs should be unique and date-based."""
        v1 = model_registry.generate_version_id()
        v2 = model_registry.generate_version_id()

        assert v1.startswith("v")
        assert "_" in v1
        # After registering v1, v2 should have incremented sequence
        model_registry.register_model(v1, None, {}, "/fake/path")
        v3 = model_registry.generate_version_id()
        assert v3 != v1

    def test_register_and_get_model(self, temp_al_workspace):
        """Should register and retrieve models."""
        version_id = "v20260130_001"
        model_registry.register_model(
            version_id=version_id,
            base_model="base_v1",
            training_config={"epochs": 10},
            path="/models/test.pt",
            status=model_registry.ModelStatus.TRAINING
        )

        model = model_registry.get_model(version_id)
        assert model is not None
        assert model["version_id"] == version_id
        assert model["base_model"] == "base_v1"
        assert model["status"] == model_registry.ModelStatus.TRAINING

    def test_promote_model(self, temp_al_workspace):
        """Promotion should update status and set as production."""
        # Create a candidate model file
        model_path = temp_al_workspace / "models" / "candidates" / "test.pt"
        model_path.write_text("fake model")

        version_id = "v20260130_001"
        model_registry.register_model(
            version_id=version_id,
            base_model=None,
            training_config={},
            path=str(model_path),
            status=model_registry.ModelStatus.EVALUATING
        )

        # Promote
        result = model_registry.promote_model(version_id)
        assert result is True

        # Check status
        model = model_registry.get_model(version_id)
        assert model["status"] == model_registry.ModelStatus.PRODUCTION

        # Check production
        prod = model_registry.get_production_model()
        assert prod is not None
        assert prod["version_id"] == version_id

    def test_list_models_by_status(self, temp_al_workspace):
        """Should filter models by status."""
        model_registry.register_model("v1", None, {}, "/p1", model_registry.ModelStatus.ARCHIVED)
        model_registry.register_model("v2", None, {}, "/p2", model_registry.ModelStatus.TRAINING)
        model_registry.register_model("v3", None, {}, "/p3", model_registry.ModelStatus.ARCHIVED)

        archived = model_registry.list_models(status=model_registry.ModelStatus.ARCHIVED)
        assert len(archived) == 2

        training = model_registry.list_models(status=model_registry.ModelStatus.TRAINING)
        assert len(training) == 1


class TestTrainingConfig:
    """Tests for training_config module."""

    def test_load_default_config(self, temp_al_workspace):
        """Should load config with defaults."""
        cfg = training_config.load_config()
        assert "epochs" in cfg
        assert "batch_size" in cfg
        assert "learning_rate" in cfg

    def test_save_and_load_config(self, temp_al_workspace):
        """Should save and reload config."""
        new_config = {"epochs": 20, "batch_size": 32}
        training_config.save_config(new_config)

        loaded = training_config.load_config()
        assert loaded["epochs"] == 20
        assert loaded["batch_size"] == 32

    def test_validate_config_valid(self, temp_al_workspace):
        """Valid config should pass validation."""
        valid_config = {
            "epochs": 10,
            "batch_size": 16,
            "learning_rate": 0.001,
            "optimizer": "Adam"
        }
        is_valid, errors = training_config.validate_config(valid_config)
        assert is_valid
        assert len(errors) == 0

    def test_validate_config_invalid(self, temp_al_workspace):
        """Invalid config should fail validation."""
        invalid_config = {
            "epochs": 500,  # Too high
            "learning_rate": 10.0,  # Too high
            "optimizer": "InvalidOpt"  # Not allowed
        }
        is_valid, errors = training_config.validate_config(invalid_config)
        assert not is_valid
        assert len(errors) > 0


class TestLabelsPool:
    """Tests for labels_pool module."""

    def test_add_and_get_label(self, temp_al_workspace):
        """Should add and retrieve labels."""
        labels_pool.add_label(
            case_id="case_001",
            image_paths=["/images/img1.jpg"],
            correct_label="mel",
            user_id="user1"
        )

        label = labels_pool.get_label_by_case("case_001")
        assert label is not None
        assert label["correct_label"] == "mel"
        assert label["user_id"] == "user1"

    def test_latest_wins_conflict_resolution(self, temp_al_workspace):
        """Same case_id should update, not duplicate."""
        labels_pool.add_label("case_001", ["/img1.jpg"], "mel", "user1")
        labels_pool.add_label("case_001", ["/img1.jpg"], "nv", "user2")  # Update

        all_labels = labels_pool.get_all_labels()
        assert len(all_labels) == 1  # Only one entry
        assert all_labels[0]["correct_label"] == "nv"  # Latest wins

    def test_get_unused_labels(self, temp_al_workspace):
        """Should track which labels have been used."""
        labels_pool.add_label("case_001", ["/img1.jpg"], "mel", "user1")
        labels_pool.add_label("case_002", ["/img2.jpg"], "nv", "user1")

        unused = labels_pool.get_unused_labels()
        assert len(unused) == 2

        # Mark one as used
        labels_pool.mark_labels_used("v_001", ["case_001"])

        unused = labels_pool.get_unused_labels()
        assert len(unused) == 1
        assert unused[0]["case_id"] == "case_002"

    def test_track_image_retrain_rounds(self, temp_al_workspace):
        """Should track retrain rounds per image path."""
        labels_pool.add_label("case_001", ["/img1.jpg", "/img2.jpg"], "mel", "user1")

        labels_pool.mark_labels_used("v_001", ["case_001"])
        labels_pool.mark_labels_used("v_002", ["case_001"])
        labels_pool.mark_labels_used("v_002", ["case_001"])  # no duplicates

        label = labels_pool.get_label_by_case("case_001")
        assert label is not None

        image_history = label.get(config.AL_IMAGE_RETRAIN_HISTORY_FIELD, {})
        assert image_history["/img1.jpg"] == ["v_001", "v_002"]
        assert image_history["/img2.jpg"] == ["v_001", "v_002"]


class TestEventLog:
    """Tests for event_log module."""

    def test_log_and_get_events(self, temp_al_workspace):
        """Should log and retrieve events."""
        event_log.log_event("test_event", "Test message", {"key": "value"})

        events = event_log.get_recent_events(limit=10)
        assert len(events) == 1
        assert events[0]["type"] == "test_event"
        assert events[0]["message"] == "Test message"

    def test_get_events_by_type(self, temp_al_workspace):
        """Should filter events by type."""
        event_log.log_event("type_a", "Message A")
        event_log.log_event("type_b", "Message B")
        event_log.log_event("type_a", "Message A2")

        type_a_events = event_log.get_events_by_type("type_a")
        assert len(type_a_events) == 2

    def test_convenience_functions(self, temp_al_workspace):
        """Convenience functions should log correct types."""
        event_log.log_training_completed("v001", 0.95, 100)
        event_log.log_model_promoted("v001", 0.95)

        events = event_log.get_recent_events()
        types = [e["type"] for e in events]
        assert event_log.EventType.TRAINING_COMPLETED in types
        assert event_log.EventType.MODEL_PROMOTED in types


class TestAutoPromote:
    """Tests for auto_promote module."""

    def test_compare_models_no_production(self, temp_al_workspace):
        """Any candidate is better than no production."""
        # Register a candidate with metrics
        model_registry.register_model("v001", None, {}, "/p", model_registry.ModelStatus.EVALUATING)
        model_registry.update_model_metrics("v001", {"val_accuracy": 0.85})

        should_promote, cand_val, prod_val = auto_promote.compare_models("v001")
        assert should_promote is True
        assert cand_val == 0.85
        assert prod_val == 0.0

    def test_evaluate_and_promote(self, temp_al_workspace):
        """Should promote better model automatically."""
        # Create candidate file
        model_path = temp_al_workspace / "models" / "candidates" / "v001" / "model.pt"
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model_path.write_text("fake")

        # Register candidate
        model_registry.register_model("v001", None, {}, str(model_path), model_registry.ModelStatus.EVALUATING)
        model_registry.update_model_metrics("v001", {"val_accuracy": 0.90})

        # Evaluate and promote
        result = auto_promote.evaluate_and_promote("v001", auto_promote=True)

        assert result["success"] is True
        assert result["promoted"] is True

        # Check event was logged
        events = event_log.get_events_by_type(event_log.EventType.MODEL_PROMOTED)
        assert len(events) >= 1


class TestFullWorkflow:
    """Integration test for complete AL workflow."""

    def test_label_to_promotion_workflow(self, temp_al_workspace):
        """
        Full workflow:
        1. Add labels
        2. Check threshold
        3. Register trained model
        4. Evaluate and promote
        5. Verify events
        """
        # Step 1: Add labels
        for i in range(15):
            labels_pool.add_label(
                case_id=f"case_{i:03d}",
                image_paths=[f"/images/img_{i}.jpg"],
                correct_label="mel" if i % 2 == 0 else "nv",
                user_id="doctor1"
            )

        assert labels_pool.get_label_count() == 15

        # Step 2: Simulate training completed - register model
        model_path = temp_al_workspace / "models" / "candidates" / "v_test" / "model.pt"
        model_path.parent.mkdir(parents=True, exist_ok=True)
        model_path.write_text("trained model weights")

        version_id = "v_test_001"
        model_registry.register_model(
            version_id=version_id,
            base_model=None,
            training_config=training_config.load_config(),
            path=str(model_path),
            status=model_registry.ModelStatus.EVALUATING
        )
        model_registry.update_model_metrics(version_id, {
            "val_accuracy": 0.92,
            "train_accuracy": 0.95,
            "samples_used": 15
        })

        # Log training completed
        event_log.log_training_completed(version_id, 0.92, 15)

        # Step 3: Evaluate and promote
        result = auto_promote.evaluate_and_promote(version_id, auto_promote=True)
        assert result["promoted"] is True

        # Step 4: Verify production
        production = model_registry.get_production_model()
        assert production is not None
        assert production["version_id"] == version_id

        # Step 5: Verify events were logged
        all_events = event_log.get_all_events()
        event_types = [e["type"] for e in all_events]
        assert event_log.EventType.TRAINING_COMPLETED in event_types
        assert event_log.EventType.MODEL_PROMOTED in event_types

        # Step 6: Check health
        health = auto_promote.check_production_health()
        assert health["healthy"] is True
        assert health["production_model"] == version_id


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
