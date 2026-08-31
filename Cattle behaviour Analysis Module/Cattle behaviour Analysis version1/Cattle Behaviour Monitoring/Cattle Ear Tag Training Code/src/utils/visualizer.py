from typing import List, Tuple, Optional
import cv2
import numpy as np


class Visualizer:
    """
    Renders clean, readable bounding boxes and tag annotations onto images.
    """

    def __init__(
        self,
        box_color: Tuple[int, int, int] = (0, 215, 255),       # Vibrant Amber/Yellow (BGR)
        text_color: Tuple[int, int, int] = (0, 0, 0),          # Black text
        bg_color: Tuple[int, int, int] = (0, 215, 255),        # Box match
        thickness: int = 2,
        font_scale: float = 0.6
    ):
        self.box_color = box_color
        self.text_color = text_color
        self.bg_color = bg_color
        self.thickness = thickness
        self.font_scale = font_scale

    def draw_detection(
        self,
        image: np.ndarray,
        box: List[int],
        label: str,
        det_conf: Optional[float] = None,
        ocr_conf: Optional[float] = None
    ) -> np.ndarray:
        """
        Draws a bounding box and label pill with text and confidence scores.
        
        Args:
            image: OpenCV BGR image (modified in-place and returned)
            box: [x1, y1, x2, y2]
            label: Text string (e.g. tag ID)
            det_conf: YOLO detection confidence score
            ocr_conf: EasyOCR text confidence score
            
        Returns:
            Annotated image array.
        """
        annotated = image.copy()
        x1, y1, x2, y2 = map(int, box)

        # 1. Draw outer bounding box
        cv2.rectangle(annotated, (x1, y1), (x2, y2), self.box_color, self.thickness)

        # 2. Build display text string
        parts = [label]
        if det_conf is not None:
            parts.append(f"det:{det_conf:.2f}")
        if ocr_conf is not None and ocr_conf > 0:
            parts.append(f"ocr:{ocr_conf:.2f}")
        caption = " | ".join(parts)

        # 3. Compute text size for pill background
        font = cv2.FONT_HERSHEY_SIMPLEX
        (tw, th), baseline = cv2.getTextSize(caption, font, self.font_scale, 1)

        # Position pill above bbox, or inside if too close to top edge
        pill_y1 = max(0, y1 - th - baseline - 6)
        pill_y2 = y1 if y1 - th - baseline - 6 >= 0 else y1 + th + baseline + 6
        pill_x2 = min(image.shape[1], x1 + tw + 10)

        # 4. Draw pill background rectangle
        cv2.rectangle(annotated, (x1, pill_y1), (pill_x2, pill_y2), self.bg_color, -1)

        # 5. Put text
        text_y = pill_y2 - baseline - 3 if y1 - th - baseline - 6 >= 0 else pill_y1 + th + 3
        cv2.putText(
            annotated,
            caption,
            (x1 + 5, text_y),
            font,
            self.font_scale,
            self.text_color,
            1,
            cv2.LINE_AA
        )

        return annotated
