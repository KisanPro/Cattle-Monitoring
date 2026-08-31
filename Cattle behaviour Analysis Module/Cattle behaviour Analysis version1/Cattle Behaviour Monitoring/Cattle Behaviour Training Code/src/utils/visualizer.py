"""
visualizer.py
OpenCV drawing utilities for rendering cattle tracking overlays on video frames.
Replaces the repeated cv2.putText / cv2.rectangle blocks spread across all
inference scripts.
"""

from __future__ import annotations

import cv2
import numpy as np


# ---------------------------------------------------------------------------
# Colours (BGR)
# ---------------------------------------------------------------------------
COLOR_COW    = (0, 255, 0)    # green
COLOR_PERSON = (255, 0, 0)    # blue
COLOR_OTHER  = (0, 165, 255)  # orange
COLOR_LABEL  = (0, 0, 255)    # red  - behaviour text
COLOR_UNCERTAIN = (0, 165, 255)  # orange - uncertain prediction text


def draw_cow_overlay(
    frame: np.ndarray,
    box: tuple[int, int, int, int],
    track_id: int,
    labels: list[str],
    font_scale: float = 0.9,
    thickness: int = 2,
) -> np.ndarray:
    """Draw a bounding box, cow ID, and behaviour label(s) for a detected cow.

    Args:
        frame:      BGR frame (modified in-place).
        box:        Bounding box ``(x1, y1, x2, y2)``.
        track_id:   YOLO track ID for this cow.
        labels:     List of behaviour strings to display (one per row).
                    e.g. ``["Posture: Standing", "Feeding: Feeding_Behaviour"]``
        font_scale: OpenCV font scale.
        thickness:  Line and text thickness.

    Returns:
        The annotated frame (same object as ``frame``).
    """
    x1, y1, x2, y2 = box

    # Bounding box
    cv2.rectangle(frame, (x1, y1), (x2, y2), COLOR_COW, thickness)

    # Cow ID (above box)
    cv2.putText(
        frame,
        f"Cow {track_id}",
        (x1, max(y1 - 60, 10)),
        cv2.FONT_HERSHEY_SIMPLEX,
        font_scale,
        COLOR_COW,
        thickness,
    )

    # Behaviour labels (stacked rows)
    row_height = 28
    for i, label_text in enumerate(labels):
        color = COLOR_UNCERTAIN if "Uncertain" in label_text else COLOR_LABEL
        y_pos = max(y1 - 30 + i * row_height, 10)
        cv2.putText(
            frame,
            label_text,
            (x1, y_pos),
            cv2.FONT_HERSHEY_SIMPLEX,
            font_scale,
            color,
            thickness,
        )

    return frame


def draw_person_overlay(
    frame: np.ndarray,
    box: tuple[int, int, int, int],
    track_id: int,
    font_scale: float = 0.9,
    thickness: int = 2,
) -> np.ndarray:
    """Draw a bounding box and label for a detected person.

    Args:
        frame:      BGR frame (modified in-place).
        box:        Bounding box ``(x1, y1, x2, y2)``.
        track_id:   YOLO track ID.
        font_scale: OpenCV font scale.
        thickness:  Line and text thickness.

    Returns:
        The annotated frame.
    """
    x1, y1, x2, y2 = box
    cv2.rectangle(frame, (x1, y1), (x2, y2), COLOR_PERSON, thickness)
    cv2.putText(
        frame,
        f"Person {track_id}",
        (x1, max(y1 - 10, 10)),
        cv2.FONT_HERSHEY_SIMPLEX,
        font_scale,
        COLOR_PERSON,
        thickness,
    )
    return frame


def draw_other_overlay(
    frame: np.ndarray,
    box: tuple[int, int, int, int],
    label: str,
    track_id: int,
    font_scale: float = 0.9,
    thickness: int = 2,
) -> np.ndarray:
    """Draw a bounding box and label for any other detected animal/object.

    Args:
        frame:      BGR frame (modified in-place).
        box:        Bounding box ``(x1, y1, x2, y2)``.
        label:      YOLO class name.
        track_id:   YOLO track ID.
        font_scale: OpenCV font scale.
        thickness:  Line and text thickness.

    Returns:
        The annotated frame.
    """
    x1, y1, x2, y2 = box
    cv2.rectangle(frame, (x1, y1), (x2, y2), COLOR_OTHER, thickness)
    cv2.putText(
        frame,
        f"{label} {track_id}",
        (x1, max(y1 - 10, 10)),
        cv2.FONT_HERSHEY_SIMPLEX,
        font_scale,
        COLOR_OTHER,
        thickness,
    )
    return frame
