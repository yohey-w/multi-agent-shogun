#!/usr/bin/env python3
"""機微情報マスキングスクリプト — スクショ内の機密情報を黒塗りする"""
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(
        description="スクショ内の機微情報を矩形で塗りつぶす",
        epilog='例: mask_sensitive.py --input shot.png --output masked.png --regions "100,50,400,80" "500,200,800,230"',
    )
    parser.add_argument("--input", required=True, help="入力画像のパス")
    parser.add_argument("--output", required=True, help="出力画像のパス")
    parser.add_argument(
        "--regions",
        nargs="+",
        required=True,
        help='マスク領域 "x1,y1,x2,y2"（複数指定可。左上(0,0)基準、ピクセル値）',
    )
    parser.add_argument(
        "--color",
        default="0,0,0",
        help='塗りつぶし色 "R,G,B"（デフォルト: 0,0,0 = 黒）',
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="マスク領域を赤枠で表示（塗りつぶさない。位置確認用）",
    )
    args = parser.parse_args()

    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print(
            "ERROR: Pillow が未インストールです。以下のコマンドでインストールしてください:",
            file=sys.stderr,
        )
        print("  pip install Pillow", file=sys.stderr)
        sys.exit(1)

    # 色のパース
    try:
        fill_color = tuple(int(v.strip()) for v in args.color.split(","))
        if len(fill_color) != 3:
            raise ValueError
    except ValueError:
        print(
            'ERROR: --color は "R,G,B" 形式で指定してください（例: "0,0,0"）',
            file=sys.stderr,
        )
        sys.exit(1)

    # 画像読み込み
    try:
        img = Image.open(args.input)
    except FileNotFoundError:
        print(f"ERROR: 入力ファイルが見つかりません: {args.input}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: 画像を開けません: {e}", file=sys.stderr)
        sys.exit(1)

    w, h = img.size
    draw = ImageDraw.Draw(img)
    masked_count = 0

    for i, region in enumerate(args.regions, 1):
        try:
            coords = tuple(int(v.strip()) for v in region.split(","))
            if len(coords) != 4:
                raise ValueError
            x1, y1, x2, y2 = coords
        except ValueError:
            print(
                f'ERROR: 領域{i} "{region}" は "x1,y1,x2,y2" 形式で指定してください',
                file=sys.stderr,
            )
            sys.exit(1)

        # 座標をクランプ
        x1 = max(0, min(x1, w))
        y1 = max(0, min(y1, h))
        x2 = max(x1, min(x2, w))
        y2 = max(y1, min(y2, h))

        if args.preview:
            # プレビューモード: 赤枠で表示
            draw.rectangle([x1, y1, x2, y2], outline=(255, 0, 0), width=3)
        else:
            # マスクモード: 塗りつぶし
            draw.rectangle([x1, y1, x2, y2], fill=fill_color)
        masked_count += 1

    img.save(args.output)
    mode = "preview" if args.preview else "masked"
    print(f"OK: {args.output} ({w}x{h}, {masked_count} regions {mode})")


if __name__ == "__main__":
    main()
