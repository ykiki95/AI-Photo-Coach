import torch
import warnings
import os

warnings.filterwarnings("ignore")
os.makedirs('android/app/src/main/assets', exist_ok=True)

from mobile_sam import sam_model_registry
model = sam_model_registry['vit_t'](checkpoint='mobile_sam.pt')
model.eval()
print('모델 로드 완료')

# === Encoder ===
print('Encoder export 중...')
encoder = model.image_encoder
dummy = torch.randn(1, 3, 1024, 1024)
torch.onnx.export(
    encoder, dummy,
    'android/app/src/main/assets/mobile_sam_encoder.onnx',
    opset_version=13,
    input_names=['input_image'],
    output_names=['image_embeddings'],
    dynamo=False,
)
size = os.path.getsize('android/app/src/main/assets/mobile_sam_encoder.onnx') / 1024 / 1024
print(f'Encoder 완료: {size:.1f}MB')

# === Decoder ===
print('Decoder export 중...')
from mobile_sam.utils.onnx import SamOnnxModel
onnx_model = SamOnnxModel(model=model, return_single_mask=True)

dummy_inputs = (
    torch.randn(1, 256, 64, 64),
    torch.randint(0, 1024, (1, 2, 2), dtype=torch.float),
    torch.tensor([[1, 0]], dtype=torch.float),
    torch.randn(1, 1, 256, 256),
    torch.tensor([0.0]),
    torch.tensor([1024.0, 1024.0]),
)

input_names = ['image_embeddings', 'point_coords', 'point_labels', 'mask_input', 'has_mask_input', 'orig_im_size']
output_names = ['masks', 'iou_predictions', 'low_res_masks']

torch.onnx.export(
    onnx_model,
    dummy_inputs,
    'android/app/src/main/assets/mobile_sam_decoder.onnx',
    opset_version=13,
    input_names=input_names,
    output_names=output_names,
    dynamic_axes={
        'point_coords': {1: 'num_points'},
        'point_labels': {1: 'num_points'},
    },
    dynamo=False,
)
size = os.path.getsize('android/app/src/main/assets/mobile_sam_decoder.onnx') / 1024 / 1024
print(f'Decoder 완료: {size:.1f}MB')
print('모든 모델 export 성공!')