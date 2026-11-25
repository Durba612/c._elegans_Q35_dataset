# c._elegans_Q35_dataset
Teacher–student YOLO11 pipeline for detecting C. elegans aggregates in fluorescence microscopy: a tiled teacher trained on 9 annotated images, pseudo-labels for an augmented 5k-image set, student models and evaluation code (AP30/50/75, P/R).

# Pseudo-labelling *C. elegans* aggregates with a teacher–student YOLO pipeline

Detection of *C. elegans* aggregates in fluorescence microscopy images. A small manually annotated set is used to train a teacher YOLO model, which labels a large augmented image set; student models are then trained on these pseudo-labels. This repository contains the code and links to the dataset described in [paper citation / DOI].

## Pipeline

![Pipeline overview](docs/pipeline.png)

1. **Partition.** 116 source images are split at the image level into 92 training images (not annotated), 12 validation images (manually annotated) and 12 test images (reserved). The 12 validation images are divided into 9 development images and 3 held-out images.
2. **Augmentation of the 92 training images.** Quadrant split (460 images), removal of 91 entirely black quadrants (369), rotation from 10° to 350° in 10° steps (13,284), four intensity versions (53,136) plus 4,098 noisy copies: **57,234 images** in total.
3. **Subsampling.** Every 11th image of the full pool is used for training: [5,203] images.
4. **Teacher.** YOLO11n trained on 1280 × 1280 tiles of the 9 development images. Three fold models (6 train / 3 validation images each) estimate generalisation; the final teacher uses all 9 images.
5. **Pseudo-labels.** The teacher labels the subsample; detections with confidence ≥ τ are kept, with τ = 0.05, 0.2 and 0.4.
6. **Students.** One student YOLO model is trained per τ, validated on the 9 development images, and evaluated on the 3 held-out images [and the 12 test images].

## Data

| Component | Content |
|---|---|
| Source images | 116 fluorescence images (92 / 12 / 12) |
| Manual annotations | 12 validation images [and 12 test images], YOLO format |
| Pseudo-labelled subsample | [5,203] images with teacher detections and confidences |
| Full augmented pool | 57,234 images, regenerated with the code in `[scripts/]` |

* **Data & Weights Download:** All image datasets and trained model weights are hosted on Google Drive — **[Download Dataset & Weights](YOUR_GOOGLE_DRIVE_LINK)**.
* Annotation format: one `.txt` file per image, each line `class x_centre y_centre width height` (normalised, class 0 = aggregate). Pseudo-label files have a sixth column with the detection confidence; an empty file means no detection.

## Repository structure

```
worm_yolo_on_yolo.ipynb               Teacher training, cross-validation, labelling, student training and evaluation
val_manual_label.m                    MATLAB script for manual annotation of the 12 validation images
fixed_aug_new.m                       MATLAB script for regenerating the full augmented image pool
DATASET_AND_WEIGHTS_LINK.md           Direct Google Drive links to the full dataset and trained model weights
results.pdf                           Summary figures, evaluation tables, and performance plots
```

## Getting started

```bash
pip install ultralytics
```

1. Download the data and set the paths at the top of the notebook [variable names].
2. Run the notebook sections in order: [partition → tiles → cross-validation → teacher → labelling → students → evaluation].
3. Labelling a folder of images with the teacher:

```python
from ultralytics import YOLO
model = YOLO("weights/teacher.pt")
model.predict(source="images/", imgsz=[imgsz], conf=0.05, iou=0.6, max_det=300,
              save_txt=True, save_conf=True)
```

A GPU is needed for labelling and training (a Colab T4 is enough). Labelling on CPU takes several seconds per image.

## Evaluation

All models are evaluated with the same code. Predictions are matched one-to-one to manual boxes by decreasing confidence, and AP uses 101-point interpolation. We report AP25, AP30, AP50, AP75, mAP50–95, and precision and recall at IoU 0.30 and 0.50 at fixed inference confidence c = 0.2 and 0.4, plus F1.

## Results

| Model | Evaluated on | mAP50 | mAP50–95 | P30 / R30 | P50 / R50 |
|---|---|---|---|---|---|
| Fold models (3) | their 3 validation images | – | – | – | – |
| Teacher | 9 development images (training set) | – | – | – | – |
| Teacher | 3 held-out images | – | – | – | – |
| Student (τ = 0.05 / 0.2 / 0.4) | 9 development images | – | – | – | – |
| Student (τ = 0.05 / 0.2 / 0.4) | 3 held-out images | – | – | – | – |

## Limitations

- Manual ground truth exists for only [12] images; pseudo-labels were not manually verified.
- The 9 development images were used to train the teacher, so student scores on them are not independent. The held-out images are the primary evidence.
- Augmented images come from 92 source images. Split them at the source-image level, never at random.

## Citation

[Authors. Title. Journal/repository. Year. DOI]

## Licence

Code: [e.g. MIT]. Data: [e.g. CC BY 4.0].

## Acknowledgements

School of Biosciences and Bioengineering, IIT Mandi. [Funding.]
