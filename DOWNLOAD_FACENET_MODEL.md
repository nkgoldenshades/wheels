# Download FaceNet Model

## Step 1: Download the model file

Download one of these models:

### Option A: MobileFaceNet (Recommended - smaller, faster)
https://github.com/sirius-ai/MobileFaceNet_TF/raw/master/MobileFaceNet_9925_9680.tflite

### Option B: FaceNet
https://github.com/patlevin/face-detection-tflite/raw/main/assets/mobilefacenet.tflite

### Option C: Google's FaceNet
https://tfhub.dev/tensorflow/lite-model/facenet/1/default/1

## Step 2: Save the file

1. Download the `.tflite` file from one of the links above
2. Save it to: `assets/models/mobilefacenet.tflite`

## Step 3: Update pubspec.yaml

Add this to your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/mobilefacenet.tflite
```

## Step 4: I'll update the face matching service

Once you've downloaded the model, let me know and I'll update the code to use it.

## Manual Download Instructions:

1. Open this link in your browser:
   https://github.com/sirius-ai/MobileFaceNet_TF/raw/master/MobileFaceNet_9925_9680.tflite

2. It will download a file

3. Rename it to `mobilefacenet.tflite`

4. Move it to `C:\codings\quickohunt\assets\models\mobilefacenet.tflite`

5. Tell me when done!
