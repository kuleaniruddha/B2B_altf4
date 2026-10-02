# Flutter Reference Integration

This folder contains a reference-only Dart integration for `tflite_flutter`.

## Service flow

1. Load image and EXIF.
2. Run authenticity heuristics.
3. Compute dHash.
4. Run detector TFLite model.
5. Crop waste regions and run classifier.
6. Build `SubmissionPayload`.
7. Upload the image to Cloud Storage.
8. Send the verification request with the storage URI and metadata.

## Assumptions

- Detector input: `512x512`
- Detector threshold: `0.35`
- Detector NMS: handled in Dart if not embedded in the graph
- Classifier input: `224x224`
- Classifier output: top-1 label plus full score map
