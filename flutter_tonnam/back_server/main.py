from fastapi import FastAPI, File, UploadFile, HTTPException
import cv2
import numpy as np
import io

# 1. แก้ไขจุดนี้: ลบคำว่า Flask ออก เพราะเราใช้ FastAPI
app = FastAPI()

def get_blur_score(image):
    """
    ฟังก์ชันคำนวณค่าความชัด (Laplacian Variance)
    ค่ายิ่งเยอะ ยิ่งชัด
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    score = cv2.Laplacian(gray, cv2.CV_64F).var()
    return score

@app.post("/check-image")
async def check_image(file: UploadFile = File(...)):
    # อ่านไฟล์ภาพที่ส่งมา
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image file")

    # 2. คำนวณคะแนนความชัดออกมาเป็นตัวเลขก่อน
    blur_score = get_blur_score(img)
    
    print(f"Blur Score: {blur_score}") # ปริ้นดูค่าใน Terminal

    # 3. ตรวจสอบเงื่อนไข (Threshold = 100.0)
    # ถ้าคะแนนน้อยกว่า 100 ถือว่า "เบลอ"
    if blur_score < 100.0:
        return {
            "status": "fail", 
            "message": "Image is too blurry", 
            "score": blur_score  # ส่งค่าคะแนนจริงกลับไป
        }
    else:
        return {
            "status": "success", 
            "message": "Image is good",
            "score": blur_score
        }

if __name__ == "__main__":
    import uvicorn
    # รันเซิร์ฟเวอร์
    uvicorn.run(app, host="0.0.0.0", port=8000)