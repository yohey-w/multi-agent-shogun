#!/usr/bin/env python3
"""画像トリミングスクリプト — shogun-screenshot スキル用"""
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="画像をトリミングする")
    parser.add_argument("--input", required=True, help="入力画像のパス")
    parser.add_argument("--output", required=True, help="出力画像のパス")
    parser.add_argument("--crop", required=True,
                        help='トリミング座標 "x1,y1,x2,y2"（左上(0,0)基準、ピクセル値）')
    parser.add_argument("--resize", default=None,
                        help='リサイズ "width,height"（省略時はトリミングのみ）')
    args = parser.parse_args()

    try:
        from PIL import Image
    except ImportError:
        print("ERROR: Pillow が未インストールです。以下のコマンドでインストールしてください:", file=sys.stderr)
        print("  pip install Pillow", file=sys.stderr)
        sys.exit(1)

    try:
        coords = tuple(int(v.strip()) for v in args.crop.split(","))
        if len(coords) != 4:
            raise ValueError
        x1, y1, x2, y2 = coords
    except ValueError:
        print('ERROR: --crop は "x1,y1,x2,y2" 形式で指定してください（例: "100,50,800,600"）', file=sys.stderr)
        sys.exit(1)

    try:
        img = Image.open(args.input)
    except FileNotFoundError:
        print(f"ERROR: 入力ファイルが見つかりません: {args.input}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: 画像を開けません: {e}", file=sys.stderr)
        sys.exit(1)

    w, h = img.size
    x1 = max(0, min(x1, w))
    y1 = max(0, min(y1, h))
    x2 = max(x1, min(x2, w))
    y2 = max(y1, min(y2, h))

    cropped = img.crop((x1, y1, x2, y2))

    if args.resize:
        try:
            rw, rh = (int(v.strip()) for v in args.resize.split(","))
            cropped = cropped.resize((rw, rh), Image.LANCZOS)
        except ValueError:
            print('ERROR: --resize は "width,height" 形式で指定してください', file=sys.stderr)
            sys.exit(1)

    cropped.save(args.output)
    print(f"OK: {args.output} ({cropped.size[0]}x{cropped.size[1]})")

if __name__ == "__main__":
    main()
