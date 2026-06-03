import pyrealsense2 as rs
import numpy as np
import cv2

def main():
    # 1. إعداد وتكوين تدفق البيانات (Pipeline)
    pipeline = rs.pipeline()
    config = rs.config()

    # تفعيل تدفق العمق (Depth) والألوان (Color) بدقة 640x480
    config.enable_stream(rs.stream.depth, 640, 480, rs.format.z16, 30)
    config.enable_stream(rs.stream.color, 640, 480, rs.format.bgr8, 30)

    # بدء الاتصال بالكاميرا
    print("جاري الاتصال بكاميرا Intel RealSense...")
    pipeline.start(config)

    try:
        while True:
            # 2. انتظار الحصول على إطارات جديدة
            frames = pipeline.wait_for_frames()
            depth_frame = frames.get_depth_frame()
            color_frame = frames.get_color_frame()

            if not depth_frame or not color_frame:
                continue

            # 3. تحويل الإطارات إلى مصفوفات Numpy لتتوافق مع OpenCV
            depth_image = np.asanyarray(depth_frame.get_data())
            color_image = np.asanyarray(color_frame.get_data())

            # 4. حساب المسافة لنقطة معينة (سنستخدم مركز الصورة هنا)
            height, width = depth_image.shape
            center_x, center_y = int(width / 2), int(height / 2)
            
            # جلب المسافة بالمتر
            distance = depth_frame.get_distance(center_x, center_y)

            # 5. عرض البيانات على الصورة
            # رسم دائرة صغيرة في المنتصف لتحديد مكان القياس
            cv2.circle(color_image, (center_x, center_y), 5, (0, 255, 0), -1)
            
            # تجهيز النص وطباعته على الصورة
            text = f"Distance: {distance:.3f} meters"
            cv2.putText(color_image, text, (center_x - 100, center_y - 20), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

            # تلوين إطار العمق لعرضه بشكل مرئي (للمراقبة فقط)
            depth_colormap = cv2.applyColorMap(cv2.convertScaleAbs(depth_image, alpha=0.03), cv2.COLORMAP_JET)

            # دمج الصورتين (الألوان والعمق) جنباً إلى جنب لعرضهما في نافذة واحدة
            images_stacked = np.hstack((color_image, depth_colormap))

            # 6. إظهار النتيجة النهائية
            cv2.imshow('RealSense Distance Measurement', images_stacked)

            # الخروج من البرنامج عند الضغط على مفتاح 'q'
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    finally:
        # إغلاق الاتصال بشكل آمن عند الانتهاء
        pipeline.stop()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()