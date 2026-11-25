# c._elegans_Q35_dataset
Teacher–student YOLO11 pipeline for detecting C. elegans aggregates in fluorescence microscopy: a tiled teacher trained on 9 annotated images, pseudo-labels for an augmented 5k-image set, student models and evaluation code (AP30/50/75, P/R).

# Pseudo-labelling *C. elegans* aggregates with a teacher–student YOLO pipeline

Detection of *C. elegans* aggregates in fluorescence microscopy images. A small manually annotated set is used to train a teacher YOLO model, which labels a large augmented image set; student models are then trained on these pseudo-labels. This repository contains the code and links to the dataset described in [paper citation / DOI].

## Pipeline



1. **Partition.** 116 source images are split at the image level into 92 training images (not annotated), 12 validation images (manually annotated). The 12 validation images are divided into 9 development images and 3 held-out images.
2. **Augmentation of the 92 training images.** Quadrant split (460 images), removal of 91 entirely black quadrants (369), rotation from 10° to 350° in 10° steps (13,284), four intensity versions (53,136) plus 4,098 noisy copies: **57,234 images** in total.
3. **Subsampling.** Every 11th image of the full pool is used for training: 5000 images.
4. **Teacher.** YOLO11n trained on 1280 × 1280 tiles of the 9 development images. Three fold models (6 train / 3 validation images each) estimate generalisation; the final teacher uses all 9 images.
5. **Pseudo-labels.** The teacher labels the subsample; detections with confidence ≥ τ are kept, with τ = 0.05, 0.2 and 0.4.
6. **Students.** One student YOLO model is trained per τ, validated on the 9 development images, evaluated on the 3 held-out images and compared against the teacher YOLO model on the 12 test images.

## Data

| Component | Content |
|---|---|
| Source images | 116 fluorescence images  |
| Manual annotations | 12 validation images, YOLO format |
| Pseudo-labelled subsample | 5000 images with teacher detections and confidences |

* **Data & Weights Download:** All image datasets and trained model weights are hosted on Google Drive — **[Download Dataset & Weights](https://drive.google.com/drive/folders/1Q7Pih6S44mR0qqXIlisk5TEFDnpykK9J?usp=sharing)**.
* Annotation format: one `.txt` file per image, each line `class x_centre y_centre width height` (normalised, class 0 = aggregate). Pseudo-label files have a sixth column with the detection confidence; an empty file means no detection.

## Repository structure

```
worm_yolo_on_yolo.ipynb               Teacher training, cross-validation, labelling, student training and evaluation
val_manual_label.m                    MATLAB script for manual annotation of the 12 validation images
fixed_aug_new.m                       MATLAB script for regenerating the full augmented image pool
DATASET_AND_WEIGHTS_LINK.md           Direct Google Drive links to the full dataset and trained model weights
results.pdf                           Summary figures, evaluation tables, and performance plots
```

## Using the model to label your own images using Python code

Install Ultralytics (we used version 8.4.218):

```bash
pip install ultralytics==8.4.218
```

1. Download a weights file from **[Download Dataset & Weights](https://drive.google.com/drive/folders/1Q7Pih6S44mR0qqXIlisk5TEFDnpykK9J?usp=sharing)** and note where you saved it.
2. Run the model on a folder of images and save the detections as YOLO label files:

```python
from ultralytics import YOLO

model = YOLO("path/to/weights.pt")      # the weights file you downloaded

results = model.predict(
    source="path/to/images",            # folder containing your images
    imgsz=2880,                         # long side in pixels (see table)
    conf=0.2,                           # minimum confidence (see table)
    iou=0.6,                            # NMS IoU threshold
    max_det=100000,                     # maximum boxes per image
    save_txt=True,                      # write YOLO label files
    save_conf=True,                     # add the confidence as a last column
    stream=True,                        # process one image at a time
    project="path/to/output", name="predict",
)
for _ in results:                       # iterating runs the prediction
    pass
```

Labels are written to `path/to/output/predict/labels/`, one `.txt` per image, with lines of the form `class x_centre y_centre width height confidence` (coordinates normalised by image size). An image without detections gets no label file.

| Parameter | What it does | Value in our experiments |
|---|---|---|
| `conf` | Minimum confidence. Lower values give more boxes (higher recall, lower precision). | τ = 0.05, 0.2 or 0.4 for pseudo-labels; c = 0.2 and 0.4 for evaluation |
| `iou` | IoU above which overlapping boxes are treated as duplicates | 0.6 |
| `max_det` | Maximum number of boxes per image. Set high so that it never limits the output. | 300 for our pseudo-labels; set higher if your images contain more objects |
| `imgsz` | Size of the longer image side seen by the model | Native resolution (2880 for our 2880 × 2048 images) |
```

A GPU is recommended for labelling and training (a Colab T4 is enough).
```

## Evaluation

All models are evaluated with the same code. Predictions are matched one-to-one to manual boxes by decreasing confidence, and AP uses 101-point interpolation. We report AP25, AP30, AP50, AP75, mAP50–95, and precision and recall at IoU 0.30 and 0.50 at fixed inference confidence c = 0.2 and 0.4, plus F1.

## Results


| Model | Evaluated on | mAP50 | mAP50–95 | P30 / R30 | P50 / R50 |
|---|---|---|---|---|---|
| Fold models (3), mean ± SD | their 3 validation images | 0.543 ± 0.111 | 0.136 ± 0.025 | 0.813 / 0.802 | 0.589 / 0.585 |
| Teacher | 9 development images (training set) | 0.816 | 0.296 | 0.892 / 0.881 | 0.789 / 0.779 |
| Teacher | 3 held-out images | 0.713 | 0.199 | 0.864 / 0.851 | 0.727 / 0.716 |
| Student (τ = 0.05) | 9 development images | 0.709 | 0.206 | 0.588 / 0.958 | 0.499 / 0.814 |
| Student (τ = 0.2) | 9 development images | 0.702 | 0.201 | 0.832 / 0.874 | 0.697 / 0.732 |
| Student (τ = 0.4) | 9 development images | 0.655 | 0.190 | 0.939 / 0.653 | 0.806 / 0.560 |
| Student (τ = 0.05) | 3 held-out images | 0.732 | 0.198 | 0.775 / 0.925 | 0.656 / 0.784 |
| Student (τ = 0.2) | 3 held-out images | 0.709 | 0.187 | 0.877 / 0.851 | 0.738 / 0.716 |
| Student (τ = 0.4) | 3 held-out images | 0.684 | 0.175 | 0.923 / 0.716 | 0.788 / 0.612 |

mAP50 and mAP50–95 are computed over the full confidence range (conf ≥ 0.001). Precision (P) and recall (R) at IoU 0.30 and 0.50 are at inference confidence c = 0.2. Fold models: mean ± SD over the three folds. All models are evaluated with the same code.



## Limitations

- Manual ground truth exists for only 12 images; pseudo-labels were not manually verified.
- The 9 development images were used to train the teacher, so student scores on them are not independent. The held-out images are the primary evidence.
- Augmented images come from 92 source images. Split them at the source-image level, never at random.


## Acknowledgements

School of Biosciences and Bioengineering, IIT Mandi. 
