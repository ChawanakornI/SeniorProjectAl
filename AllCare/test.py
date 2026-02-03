"""
Comprehensive Active Learning Retraining Diagnostic Script

This script tests all components of the retraining pipeline to identify
where failures occur. Run this before attempting actual retraining.

Usage:
    python test_retrain.py
    python test_retrain.py --verbose
    python test_retrain.py --test-train  # Also runs a mini training test
"""

import os
import sys
import json
import argparse
import traceback
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import models, transforms
from PIL import Image

# Try to import your modules
try:
    from . import config
    IMPORT_MODE = "relative"
except ImportError:
    try:
        import config
        IMPORT_MODE = "direct"
    except ImportError:
        print("⚠️  Cannot import config module. Will use fallback values.")
        IMPORT_MODE = "fallback"
        
        # Fallback config
        class FallbackConfig:
            STORAGE_ROOT = "./storage"
            PROJECT_ROOT = "."
            METADATA_FILENAME = "metadata.jsonl"
            MODEL_PATH = "./model.pt"
        
        config = FallbackConfig()

try:
    if IMPORT_MODE == "relative":
        from .model import ModelService
    elif IMPORT_MODE == "direct":
        from model import ModelService
    else:
        ModelService = None
except ImportError:
    print("⚠️  Cannot import ModelService. Will skip model loading tests.")
    ModelService = None


# Color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def print_header(text: str):
    """Print a section header"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'=' * 70}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text.center(70)}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'=' * 70}{Colors.ENDC}\n")


def print_success(text: str):
    """Print success message"""
    print(f"{Colors.OKGREEN}✓ {text}{Colors.ENDC}")


def print_error(text: str):
    """Print error message"""
    print(f"{Colors.FAIL}✗ {text}{Colors.ENDC}")


def print_warning(text: str):
    """Print warning message"""
    print(f"{Colors.WARNING}⚠ {text}{Colors.ENDC}")


def print_info(text: str):
    """Print info message"""
    print(f"{Colors.OKCYAN}ℹ {text}{Colors.ENDC}")


class RetrainTester:
    """Comprehensive tester for active learning retraining pipeline"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.tests_passed = 0
        self.tests_failed = 0
        self.warnings = 0
        self.errors = []
        
        # HAM10000 class names
        self.class_to_idx = {
            "akiec": 0,
            "bcc": 1,
            "bkl": 2,
            "df": 3,
            "mel": 4,
            "nv": 5,
            "vasc": 6,
        }
    
    def run_all_tests(self, test_training: bool = False):
        """Run all diagnostic tests"""
        print_header("ACTIVE LEARNING RETRAINING DIAGNOSTIC")
        print_info(f"Import mode: {IMPORT_MODE}")
        print_info(f"Timestamp: {datetime.now().isoformat()}")
        
        # Test 1: Environment
        self.test_environment()
        
        # Test 2: Config
        self.test_config()
        
        # Test 3: Storage structure
        self.test_storage_structure()
        
        # Test 4: Labeled cases collection
        labeled_cases = self.test_labeled_cases_collection()
        
        # Test 5: Dataset creation
        dataset = self.test_dataset_creation(labeled_cases)
        
        # Test 6: DataLoader
        dataloader = self.test_dataloader(dataset)
        
        # Test 7: Model creation
        model = self.test_model_creation()
        
        # Test 8: Model loading
        self.test_model_loading()
        
        # Test 9: Retrain status
        self.test_retrain_status()
        
        # Test 10: File permissions
        self.test_file_permissions()
        
        # Test 11: Active learning module
        self.test_active_learning_module(labeled_cases)
        
        # Test 12: Mini training (optional)
        if test_training and dataset and len(dataset) > 0:
            self.test_mini_training(model, dataloader)
        
        # Print summary
        self.print_summary()
    
    def test_environment(self):
        """Test Python environment and dependencies"""
        print_header("Test 1: Environment & Dependencies")
        
        try:
            # Python version
            print_info(f"Python version: {sys.version}")
            
            # PyTorch
            print_info(f"PyTorch version: {torch.__version__}")
            print_success("PyTorch installed")
            
            # CUDA availability
            if torch.cuda.is_available():
                print_success(f"CUDA available: {torch.cuda.get_device_name(0)}")
                print_info(f"CUDA version: {torch.version.cuda}")
            else:
                print_warning("CUDA not available, will use CPU")
            
            # Device
            device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
            print_info(f"Default device: {device}")
            
            # Memory
            if torch.cuda.is_available():
                mem_allocated = torch.cuda.memory_allocated(0) / 1024**3
                mem_reserved = torch.cuda.memory_reserved(0) / 1024**3
                print_info(f"GPU memory: {mem_allocated:.2f}GB allocated, {mem_reserved:.2f}GB reserved")
            
            # PIL
            print_success("PIL (Pillow) installed")
            
            self.tests_passed += 1
            
        except Exception as e:
            print_error(f"Environment test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("Environment", str(e)))
    
    def test_config(self):
        """Test configuration"""
        print_header("Test 2: Configuration")
        
        try:
            required_attrs = ['STORAGE_ROOT', 'PROJECT_ROOT', 'METADATA_FILENAME']
            optional_attrs = ['MODEL_PATH']
            
            for attr in required_attrs:
                if hasattr(config, attr):
                    value = getattr(config, attr)
                    print_success(f"config.{attr} = {value}")
                else:
                    print_error(f"config.{attr} is missing")
                    self.tests_failed += 1
                    self.errors.append(("Config", f"Missing {attr}"))
                    return
            
            for attr in optional_attrs:
                if hasattr(config, attr):
                    value = getattr(config, attr)
                    print_info(f"config.{attr} = {value}")
                else:
                    print_warning(f"config.{attr} not set (optional)")
            
            self.tests_passed += 1
            
        except Exception as e:
            print_error(f"Config test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("Config", str(e)))
    
    def test_storage_structure(self):
        """Test storage directory structure"""
        print_header("Test 3: Storage Structure")
        
        try:
            storage_root = Path(config.STORAGE_ROOT)
            
            if not storage_root.exists():
                print_warning(f"Storage root does not exist: {storage_root}")
                print_info("This is OK if no data has been labeled yet")
                self.warnings += 1
                return
            
            print_success(f"Storage root exists: {storage_root}")
            
            # Count user directories
            user_dirs = [d for d in storage_root.iterdir() if d.is_dir()]
            print_info(f"Found {len(user_dirs)} user directories")
            
            if len(user_dirs) == 0:
                print_warning("No user directories found")
                self.warnings += 1
                return
            
            # Check metadata files
            metadata_count = 0
            for user_dir in user_dirs:
                metadata_path = user_dir / config.METADATA_FILENAME
                if metadata_path.exists():
                    metadata_count += 1
                    print_success(f"Found metadata: {metadata_path}")
                else:
                    print_warning(f"No metadata in: {user_dir}")
            
            print_info(f"Total metadata files: {metadata_count}/{len(user_dirs)}")
            
            if metadata_count == 0:
                print_warning("No metadata files found")
                self.warnings += 1
            else:
                self.tests_passed += 1
            
        except Exception as e:
            print_error(f"Storage structure test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("Storage", str(e)))
    
    def test_labeled_cases_collection(self) -> List[Dict[str, Any]]:
        """Test labeled cases collection"""
        print_header("Test 4: Labeled Cases Collection")
        
        labeled_cases = []
        
        try:
            storage_root = Path(config.STORAGE_ROOT)
            
            if not storage_root.exists():
                print_warning("Storage root doesn't exist, skipping")
                return labeled_cases
            
            # Collect labeled cases (replicate the function logic)
            for user_dir in storage_root.iterdir():
                if not user_dir.is_dir():
                    continue
                
                user_id = user_dir.name
                metadata_path = user_dir / config.METADATA_FILENAME
                
                if not metadata_path.exists():
                    continue
                
                try:
                    with open(metadata_path, 'r', encoding='utf-8') as f:
                        line_num = 0
                        for line in f:
                            line_num += 1
                            line = line.strip()
                            if not line:
                                continue
                            try:
                                entry = json.loads(line)
                                
                                # Check if this is a labeled case
                                if entry.get('correct_label') and entry.get('image_paths'):
                                    entry['user_id'] = user_id
                                    labeled_cases.append(entry)
                                    
                                    if self.verbose:
                                        print_info(f"  Line {line_num}: Found labeled case")
                                        print_info(f"    Label: {entry['correct_label']}")
                                        print_info(f"    Images: {len(entry['image_paths'])}")
                                        
                            except json.JSONDecodeError as je:
                                print_warning(f"  Line {line_num}: Invalid JSON - {str(je)}")
                                
                except (OSError, IOError) as ioe:
                    print_error(f"Cannot read {metadata_path}: {str(ioe)}")
            
            print_success(f"Collected {len(labeled_cases)} labeled cases")
            
            if len(labeled_cases) == 0:
                print_warning("No labeled cases found")
                print_info("Possible reasons:")
                print_info("  1. No expert has labeled any cases yet")
                print_info("  2. Metadata format is incorrect")
                print_info("  3. 'correct_label' or 'image_paths' fields are missing")
                self.warnings += 1
            else:
                # Show sample case
                print_info("\nSample labeled case:")
                sample = labeled_cases[0]
                print_info(f"  User ID: {sample.get('user_id')}")
                print_info(f"  Correct label: {sample.get('correct_label')}")
                print_info(f"  Image paths: {sample.get('image_paths')}")
                
                # Validate labels
                invalid_labels = []
                for case in labeled_cases:
                    label = case.get('correct_label')
                    if label not in self.class_to_idx:
                        invalid_labels.append(label)
                
                if invalid_labels:
                    print_warning(f"Found {len(set(invalid_labels))} invalid labels: {set(invalid_labels)}")
                    print_info(f"Valid labels are: {list(self.class_to_idx.keys())}")
                else:
                    print_success("All labels are valid")
                
                self.tests_passed += 1
            
            return labeled_cases
            
        except Exception as e:
            print_error(f"Labeled cases collection failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("LabeledCases", str(e)))
            return labeled_cases
    
    def test_dataset_creation(self, labeled_cases: List[Dict[str, Any]]) -> Optional[Any]:
        """Test dataset creation"""
        print_header("Test 5: Dataset Creation")
        
        if len(labeled_cases) == 0:
            print_warning("No labeled cases to create dataset from")
            return None
        
        try:
            # Create transform
            transform = transforms.Compose([
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
            ])
            print_success("Transform created")
            
            # Manually create dataset to debug
            data = []
            storage_root = Path(config.STORAGE_ROOT)
            
            valid_images = 0
            invalid_images = 0
            missing_images = 0
            
            for case in labeled_cases:
                if case.get('correct_label') and case.get('image_paths'):
                    label = case['correct_label']
                    label_idx = self.class_to_idx.get(label)
                    
                    if label_idx is None:
                        print_warning(f"Invalid label: {label}")
                        invalid_images += len(case['image_paths'])
                        continue
                    
                    for image_path in case['image_paths']:
                        full_path = storage_root / case['user_id'] / image_path
                        
                        if self.verbose:
                            print_info(f"  Checking: {full_path}")
                        
                        if full_path.exists():
                            # Try to open the image
                            try:
                                img = Image.open(full_path).convert('RGB')
                                img.close()
                                data.append((str(full_path), label_idx))
                                valid_images += 1
                                if self.verbose:
                                    print_success(f"    Valid image")
                            except Exception as img_error:
                                print_warning(f"Cannot open image {full_path}: {str(img_error)}")
                                invalid_images += 1
                        else:
                            if self.verbose:
                                print_warning(f"    File not found")
                            missing_images += 1
            
            print_info(f"Dataset statistics:")
            print_info(f"  Valid images: {valid_images}")
            print_info(f"  Missing images: {missing_images}")
            print_info(f"  Invalid images: {invalid_images}")
            
            if valid_images == 0:
                print_error("No valid images found!")
                print_info("\nDebugging info:")
                print_info(f"  Storage root: {storage_root}")
                print_info(f"  Storage root exists: {storage_root.exists()}")
                
                if len(labeled_cases) > 0:
                    sample = labeled_cases[0]
                    print_info(f"\nSample path construction:")
                    print_info(f"  user_id: {sample.get('user_id')}")
                    print_info(f"  image_paths[0]: {sample.get('image_paths', ['N/A'])[0]}")
                    full_path = storage_root / sample['user_id'] / sample['image_paths'][0]
                    print_info(f"  Full path: {full_path}")
                    print_info(f"  Exists: {full_path.exists()}")
                    
                    # Check parent directories
                    parent = full_path.parent
                    print_info(f"  Parent dir: {parent}")
                    print_info(f"  Parent exists: {parent.exists()}")
                    
                    if parent.exists():
                        print_info(f"  Parent contents: {list(parent.iterdir())[:5]}")
                
                self.tests_failed += 1
                self.errors.append(("Dataset", "No valid images found"))
                return None
            
            print_success(f"Dataset created successfully with {len(data)} images")
            
            # Create a simple dataset class for testing
            class SimpleDataset:
                def __init__(self, data, transform):
                    self.data = data
                    self.transform = transform
                
                def __len__(self):
                    return len(self.data)
                
                def __getitem__(self, idx):
                    img_path, label = self.data[idx]
                    image = Image.open(img_path).convert('RGB')
                    if self.transform:
                        image = self.transform(image)
                    return image, label
            
            dataset = SimpleDataset(data, transform)
            
            # Test loading one sample
            img, label = dataset[0]
            print_success(f"Sample loaded: shape={img.shape}, label={label}")
            
            self.tests_passed += 1
            return dataset
            
        except Exception as e:
            print_error(f"Dataset creation failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("Dataset", str(e)))
            return None
    
    def test_dataloader(self, dataset) -> Optional[DataLoader]:
        """Test DataLoader creation"""
        print_header("Test 6: DataLoader")
        
        if dataset is None or len(dataset) == 0:
            print_warning("No dataset available")
            return None
        
        try:
            batch_size = min(4, len(dataset))
            dataloader = DataLoader(
                dataset, 
                batch_size=batch_size, 
                shuffle=True, 
                num_workers=0
            )
            print_success(f"DataLoader created (batch_size={batch_size})")
            
            # Test loading one batch
            for batch_imgs, batch_labels in dataloader:
                print_success(f"Batch loaded: images shape={batch_imgs.shape}, labels shape={batch_labels.shape}")
                break
            
            self.tests_passed += 1
            return dataloader
            
        except Exception as e:
            print_error(f"DataLoader test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("DataLoader", str(e)))
            return None
    
    def test_model_creation(self):
        """Test model creation"""
        print_header("Test 7: Model Creation")
        
        try:
            # Try to create a fresh model
            base_weights = getattr(models, "ResNet50_Weights", None)
            weights = base_weights.IMAGENET1K_V2 if base_weights else None
            model = models.resnet50(weights=weights)
            
            print_success("ResNet50 base model created")
            
            # Modify for HAM10000
            num_classes = 7
            in_features = model.fc.in_features
            model.fc = nn.Sequential(
                nn.Dropout(p=0.3), 
                nn.Linear(in_features, num_classes)
            )
            
            print_success(f"Modified for {num_classes} classes")
            print_info(f"Model FC layer: {model.fc}")
            
            # Test forward pass
            device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
            model.to(device)
            
            dummy_input = torch.randn(1, 3, 224, 224).to(device)
            output = model(dummy_input)
            
            print_success(f"Forward pass successful: output shape={output.shape}")
            
            self.tests_passed += 1
            return model
            
        except Exception as e:
            print_error(f"Model creation failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("ModelCreation", str(e)))
            return None
    
    def test_model_loading(self):
        """Test loading existing model"""
        print_header("Test 8: Model Loading")
        
        try:
            if not hasattr(config, 'MODEL_PATH'):
                print_warning("config.MODEL_PATH not set")
                return
            
            model_path = config.MODEL_PATH
            
            if not os.path.exists(model_path):
                print_warning(f"Model file doesn't exist: {model_path}")
                print_info("This is OK if you haven't trained a model yet")
                return
            
            print_success(f"Model file exists: {model_path}")
            
            # Check file size
            file_size = os.path.getsize(model_path) / (1024 ** 2)
            print_info(f"Model file size: {file_size:.2f} MB")
            
            # Try to load with torch
            try:
                checkpoint = torch.load(model_path, map_location='cpu')
                print_success("Model file is valid PyTorch checkpoint")
                
                if isinstance(checkpoint, dict):
                    print_info(f"Checkpoint keys: {list(checkpoint.keys())}")
                    if 'model_state_dict' in checkpoint:
                        print_success("Contains 'model_state_dict'")
                    if 'num_labeled_samples' in checkpoint:
                        print_info(f"Trained with {checkpoint['num_labeled_samples']} samples")
                
            except Exception as load_error:
                print_error(f"Cannot load model file: {str(load_error)}")
                self.errors.append(("ModelLoading", str(load_error)))
                return
            
            # Try with ModelService if available
            if ModelService is not None:
                try:
                    model_service = ModelService(model_path)
                    if model_service.model is not None:
                        print_success("ModelService loaded model successfully")
                    else:
                        print_warning("ModelService returned None for model")
                except Exception as ms_error:
                    print_error(f"ModelService failed: {str(ms_error)}")
            
            self.tests_passed += 1
            
        except Exception as e:
            print_error(f"Model loading test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("ModelLoading", str(e)))
    
    def test_retrain_status(self):
        """Test retrain status tracking"""
        print_header("Test 9: Retrain Status")
        
        try:
            status_file = Path(config.PROJECT_ROOT) / "model_retrain_status.json"
            
            if status_file.exists():
                print_success(f"Status file exists: {status_file}")
                
                with open(status_file, 'r') as f:
                    status = json.load(f)
                
                print_info("Current status:")
                for key, value in status.items():
                    print_info(f"  {key}: {value}")
                
            else:
                print_warning(f"Status file doesn't exist: {status_file}")
                print_info("This is OK if retraining hasn't been run yet")
            
            # Test should_retrain logic
            from pathlib import Path
            storage_root = Path(config.STORAGE_ROOT)
            
            if storage_root.exists():
                # Count labeled cases
                labeled_count = 0
                for user_dir in storage_root.iterdir():
                    if not user_dir.is_dir():
                        continue
                    metadata_path = user_dir / config.METADATA_FILENAME
                    if metadata_path.exists():
                        with open(metadata_path, 'r') as f:
                            for line in f:
                                if line.strip():
                                    try:
                                        entry = json.loads(line)
                                        if entry.get('correct_label') and entry.get('image_paths'):
                                            labeled_count += 1
                                    except:
                                        pass
                
                print_info(f"\nRetrain trigger analysis:")
                print_info(f"  Total labeled cases: {labeled_count}")
                
                if status_file.exists():
                    with open(status_file, 'r') as f:
                        status = json.load(f)
                    last_retrain = status.get('last_retrain_samples', 0)
                    new_samples = labeled_count - last_retrain
                    min_interval = 1  # From your code
                    
                    print_info(f"  Last retrain at: {last_retrain} samples")
                    print_info(f"  New samples: {new_samples}")
                    print_info(f"  Min interval: {min_interval}")
                    
                    should_retrain = new_samples >= min_interval
                    
                    if should_retrain:
                        print_success(f"Should retrain: YES ({new_samples} >= {min_interval})")
                    else:
                        print_warning(f"Should retrain: NO ({new_samples} < {min_interval})")
                else:
                    print_info("  No previous retraining, would trigger on first labeled case")
            
            self.tests_passed += 1
            
        except Exception as e:
            print_error(f"Retrain status test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("RetrainStatus", str(e)))
    
    def test_file_permissions(self):
        """Test file write permissions"""
        print_header("Test 10: File Permissions")
        
        try:
            # Test writing to project root
            test_file = Path(config.PROJECT_ROOT) / "test_write_permission.tmp"
            
            try:
                with open(test_file, 'w') as f:
                    f.write("test")
                print_success(f"Can write to project root: {config.PROJECT_ROOT}")
                test_file.unlink()  # Delete test file
            except Exception as write_error:
                print_error(f"Cannot write to project root: {str(write_error)}")
                self.errors.append(("Permissions", f"Cannot write to {config.PROJECT_ROOT}"))
                self.tests_failed += 1
                return
            
            # Test model directory
            if hasattr(config, 'MODEL_PATH'):
                model_dir = Path(config.MODEL_PATH).parent
                test_file = model_dir / "test_write_permission.tmp"
                
                try:
                    model_dir.mkdir(parents=True, exist_ok=True)
                    with open(test_file, 'w') as f:
                        f.write("test")
                    print_success(f"Can write to model directory: {model_dir}")
                    test_file.unlink()
                except Exception as write_error:
                    print_error(f"Cannot write to model directory: {str(write_error)}")
                    self.errors.append(("Permissions", f"Cannot write to {model_dir}"))
                    self.tests_failed += 1
                    return
            
            self.tests_passed += 1
            
        except Exception as e:
            print_error(f"Permission test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("Permissions", str(e)))
    
    def test_active_learning_module(self, labeled_cases: List[Dict[str, Any]]):
        """Test active learning module functions"""
        print_header("Test 11: Active Learning Module")
        
        try:
            # Test with mock predictions
            mock_case = {
                'case_id': 'test_123',
                'images': [
                    {
                        'path': 'test1.jpg',
                        'predictions': [
                            {'label': 'mel', 'confidence': 0.45},
                            {'label': 'nv', 'confidence': 0.40},
                            {'label': 'bcc', 'confidence': 0.15}
                        ]
                    },
                    {
                        'path': 'test2.jpg',
                        'predictions': [
                            {'label': 'bkl', 'confidence': 0.60},
                            {'label': 'df', 'confidence': 0.25},
                            {'label': 'akiec', 'confidence': 0.15}
                        ]
                    }
                ]
            }
            
            # Test margin calculation (if active_learning module is available)
            try:
                # Try to import active learning functions
                try:
                    from . import active_learning
                except ImportError:
                    import active_learning
                
                # Test calculate_margin
                predictions = mock_case['images'][0]['predictions']
                margin = active_learning.calculate_margin(predictions)
                print_success(f"calculate_margin() works: margin = {margin}")
                
                # Test calculate_case_margin
                case_margin = active_learning.calculate_case_margin(mock_case)
                print_success(f"calculate_case_margin() works: margin = {case_margin}")
                
                # Test with real labeled cases if available
                if labeled_cases:
                    # Add mock predictions to labeled cases
                    test_cases = []
                    for i, case in enumerate(labeled_cases[:3]):
                        test_case = case.copy()
                        test_case['predictions'] = [
                            {'label': 'mel', 'confidence': 0.3 + i * 0.1},
                            {'label': 'nv', 'confidence': 0.25 + i * 0.05}
                        ]
                        test_cases.append(test_case)
                    
                    result = active_learning.get_active_learning_candidates(test_cases, top_k=2)
                    print_success(f"get_active_learning_candidates() works")
                    print_info(f"  Selected {result['total_candidates']} candidates")
                    print_info(f"  Method: {result['selection_method']}")
                
                self.tests_passed += 1
                
            except ImportError:
                print_warning("Cannot import active_learning module")
                print_info("This is OK if the module is in a different location")
            
        except Exception as e:
            print_error(f"Active learning test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("ActiveLearning", str(e)))
    
    def test_mini_training(self, model, dataloader):
        """Test a mini training loop"""
        print_header("Test 12: Mini Training Loop")
        
        if model is None or dataloader is None:
            print_warning("Skipping mini training (no model or dataloader)")
            return
        
        try:
            print_info("Running 1 epoch with 5 batches max...")
            
            device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
            model.to(device)
            model.train()
            
            criterion = nn.CrossEntropyLoss()
            optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)
            
            running_loss = 0.0
            batch_count = 0
            
            for inputs, labels in dataloader:
                if batch_count >= 5:  # Only 5 batches
                    break
                
                inputs, labels = inputs.to(device), labels.to(device)
                
                optimizer.zero_grad()
                outputs = model(inputs)
                loss = criterion(outputs, labels)
                loss.backward()
                optimizer.step()
                
                running_loss += loss.item()
                batch_count += 1
                
                print_info(f"  Batch {batch_count}: loss = {loss.item():.4f}")
            
            avg_loss = running_loss / batch_count
            print_success(f"Mini training completed: avg loss = {avg_loss:.4f}")
            
            # Test model saving
            test_save_path = Path(config.PROJECT_ROOT) / "test_model_save.pt"
            torch.save({
                'model_state_dict': model.state_dict(),
                'test': True
            }, test_save_path)
            print_success(f"Model save test successful: {test_save_path}")
            
            # Clean up
            test_save_path.unlink()
            
            self.tests_passed += 1
            
        except Exception as e:
            print_error(f"Mini training test failed: {str(e)}")
            if self.verbose:
                traceback.print_exc()
            self.tests_failed += 1
            self.errors.append(("Training", str(e)))
    
    def print_summary(self):
        """Print test summary"""
        print_header("TEST SUMMARY")
        
        total_tests = self.tests_passed + self.tests_failed
        
        print_info(f"Total tests run: {total_tests}")
        print_success(f"Tests passed: {self.tests_passed}")
        
        if self.tests_failed > 0:
            print_error(f"Tests failed: {self.tests_failed}")
        
        if self.warnings > 0:
            print_warning(f"Warnings: {self.warnings}")
        
        if len(self.errors) > 0:
            print("\n" + Colors.FAIL + Colors.BOLD + "ERRORS FOUND:" + Colors.ENDC)
            for category, error in self.errors:
                print_error(f"[{category}] {error}")
        
        print("\n" + "=" * 70)
        
        if self.tests_failed == 0:
            print_success(Colors.BOLD + "ALL CRITICAL TESTS PASSED! ✓" + Colors.ENDC)
            print_info("Your retraining pipeline should work.")
            if self.warnings > 0:
                print_warning("Review warnings above for potential issues.")
        else:
            print_error(Colors.BOLD + "SOME TESTS FAILED! ✗" + Colors.ENDC)
            print_info("Fix the errors above before attempting retraining.")
        
        print("=" * 70 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Comprehensive diagnostic tool for Active Learning retraining pipeline"
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output with detailed information'
    )
    parser.add_argument(
        '--test-train',
        action='store_true',
        help='Also run a mini training test (requires valid dataset)'
    )
    
    args = parser.parse_args()
    
    tester = RetrainTester(verbose=args.verbose)
    tester.run_all_tests(test_training=args.test_train)


if __name__ == "__main__":
    main()