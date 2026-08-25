import sys
from PIL import Image

def remove_black_background(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()

    new_data = []
    for item in data:
        # Get RGB values
        r, g, b, a = item
        
        # Calculate luminance (brightness)
        brightness = max(r, g, b)
        
        if brightness == 0:
            new_data.append((0, 0, 0, 0))
        else:
            # Alpha based on brightness
            alpha = brightness
            # Un-premultiply (boost color channels so they are bright when alpha is applied)
            nr = min(255, int(r * 255 / brightness))
            ng = min(255, int(g * 255 / brightness))
            nb = min(255, int(b * 255 / brightness))
            new_data.append((nr, ng, nb, alpha))

    img.putdata(new_data)
    # Resize to 256x256 to save space in the app
    img = img.resize((256, 256), Image.Resampling.LANCZOS)
    img.save(output_path, "PNG")

if __name__ == "__main__":
    remove_black_background(sys.argv[1], sys.argv[2])
