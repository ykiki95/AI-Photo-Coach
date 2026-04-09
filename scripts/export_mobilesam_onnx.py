#!/usr/bin/env python3
"""
MobileSAM ONNX 모델 Export 스크립트

이 스크립트는 MobileSAM 체크포인트를 Android 앱용
encoder/decoder ONNX 파일로 변환합니다.

사용법:
    pip install torch torchvision onnx onnxruntime
    pip install git+https://github.com/ChaoningZhang/MobileSAM.git
    python export_mobilesam_onnx.py

출력:
    android/app/src/main/assets/mobile_sam_encoder.onnx
    android/app/src/main/assets/mobile_sam_decoder.onnx
"""

import os
import sys
import urllib.request
import torch
import numpy as np

# ────────────────────────────────────────────
# 설정
# ────────────────────────────────────────────
CHECKPOINT_URL = "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt"
CHECKPOINT_PATH = "mobile_sam.pt"
OUTPUT_DIR = "android/app/src/main/assets"
ENCODER_OUTPUT = os.path.join(OUTPUT_DIR, "mobile_sam_encoder.onnx")
DECODER_OUTPUT = os.path.join(OUTPUT_DIR, "mobile_sam_decoder.onnx")
INPUT_SIZE = 1024
OPSET_VERSION = 17


def download_checkpoint():
    """MobileSAM 체크포인트 다운로드"""
    if os.path.exists(CHECKPOINT_PATH):
        print(f"✓ 체크포인트 존재: {CHECKPOINT_PATH}")
        return

    print(f"⬇ 체크포인트 다운로드 중...")
    urllib.request.urlretrieve(CHECKPOINT_URL, CHECKPOINT_PATH)
    size_mb = os.path.getsize(CHECKPOINT_PATH) / (1024 * 1024)
    print(f"✓ 다운로드 완료: {size_mb:.1f}MB")


def export_encoder(model):
    """이미지 인코더 → ONNX export"""
    print("\n📦 Encoder export 중...")

    encoder = model.image_encoder
    encoder.eval()

    # 더미 입력: [1, 3, 1024, 1024]
    dummy_input = torch.randn(1, 3, INPUT_SIZE, INPUT_SIZE)

    torch.onnx.export(
        encoder,
        dummy_input,
        ENCODER_OUTPUT,
        opset_version=OPSET_VERSION,
        input_names=["input_image"],
        output_names=["image_embeddings"],
        dynamic_axes=None,  # 고정 크기 (모바일 최적화)
    )

    size_mb = os.path.getsize(ENCODER_OUTPUT) / (1024 * 1024)
    print(f"✓ Encoder 저장: {ENCODER_OUTPUT} ({size_mb:.1f}MB)")


def export_decoder(model):
    """마스크 디코더 → ONNX export"""
    print("\n📦 Decoder export 중...")

    from mobile_sam.utils.onnx import SamOnnxModel

    onnx_model = SamOnnxModel(
        model=model,
        return_single_mask=True,
        use_stability_score=False,
    )

    # 더미 입력
    embed_dim = 256
    embed_size = 64
    mask_input_size = [4 * x for x in (embed_size, embed_size)]
    num_points = 3  # center + box corners

    dummy_inputs = {
        "image_embeddings": torch.randn(1, embed_dim, embed_size, embed_size),
        "point_coords": torch.randint(low=0, high=INPUT_SIZE, size=(1, num_points, 2), dtype=torch.float),
        "point_labels": torch.tensor([[1, 2, 3]], dtype=torch.float),  # fg + box
        "mask_input": torch.randn(1, 1, *mask_input_size),
        "has_mask_input": torch.tensor([0.0]),
        "orig_im_size": torch.tensor([INPUT_SIZE, INPUT_SIZE], dtype=torch.float),
    }

    torch.onnx.export(
        onnx_model,
        tuple(dummy_inputs.values()),
        DECODER_OUTPUT,
        opset_version=OPSET_VERSION,
        input_names=list(dummy_inputs.keys()),
        output_names=["masks", "iou_predictions", "low_res_masks"],
        dynamic_axes={
            "point_coords": {1: "num_points"},
            "point_labels": {1: "num_points"},
        },
    )

    size_mb = os.path.getsize(DECODER_OUTPUT) / (1024 * 1024)
    print(f"✓ Decoder 저장: {DECODER_OUTPUT} ({size_mb:.1f}MB)")


def quantize_models():
    """INT8 동적 양자화 (선택사항)"""
    try:
        from onnxruntime.quantization import quantize_dynamic, QuantType

        for path in [ENCODER_OUTPUT, DECODER_OUTPUT]:
            quant_path = path.replace(".onnx", "_quant.onnx")
            quantize_dynamic(
                path,
                quant_path,
                weight_type=QuantType.QUInt8,
            )
            orig_mb = os.path.getsize(path) / (1024 * 1024)
            quant_mb = os.path.getsize(quant_path) / (1024 * 1024)
            print(f"✓ 양자화: {os.path.basename(path)} {orig_mb:.1f}MB → {quant_mb:.1f}MB")

            # 양자화 모델로 교체
            os.replace(quant_path, path)

    except ImportError:
        print("⚠ onnxruntime.quantization 없음, 양자화 건너뜀")


def verify_models():
    """ONNX 모델 검증"""
    import onnxruntime as ort

    print("\n🔍 모델 검증 중...")

    # Encoder 검증
    enc_session = ort.InferenceSession(ENCODER_OUTPUT)
    enc_input = np.random.randn(1, 3, INPUT_SIZE, INPUT_SIZE).astype(np.float32)
    enc_output = enc_session.run(None, {"input_image": enc_input})
    print(f"✓ Encoder 출력 shape: {enc_output[0].shape}")  # [1, 256, 64, 64]

    # Decoder 검증
    dec_session = ort.InferenceSession(DECODER_OUTPUT)
    dec_inputs = {
        "image_embeddings": enc_output[0],
        "point_coords": np.array([[[512.0, 512.0], [256.0, 256.0], [768.0, 768.0]]], dtype=np.float32),
        "point_labels": np.array([[1.0, 2.0, 3.0]], dtype=np.float32),
        "mask_input": np.zeros((1, 1, 256, 256), dtype=np.float32),
        "has_mask_input": np.array([0.0], dtype=np.float32),
        "orig_im_size": np.array([1024.0, 1024.0], dtype=np.float32),
    }
    dec_output = dec_session.run(None, dec_inputs)
    print(f"✓ Decoder 출력 shape: masks={dec_output[0].shape}, iou={dec_output[1].shape}")

    print("\n✅ 모든 모델 검증 완료!")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. 체크포인트 다운로드
    download_checkpoint()

    # 2. 모델 로드
    print("\n🔧 MobileSAM 모델 로딩...")
    from mobile_sam import sam_model_registry

    model = sam_model_registry["vit_t"](checkpoint=CHECKPOINT_PATH)
    model.eval()
    print("✓ 모델 로드 완료")

    # 3. Export
    export_encoder(model)
    export_decoder(model)

    # 4. 양자화 (선택)
    if "--quantize" in sys.argv:
        quantize_models()

    # 5. 검증
    if "--verify" in sys.argv or "--quantize" not in sys.argv:
        verify_models()

    print(f"\n🎉 완료! 파일 위치:")
    print(f"   {ENCODER_OUTPUT}")
    print(f"   {DECODER_OUTPUT}")


if __name__ == "__main__":
    main()
