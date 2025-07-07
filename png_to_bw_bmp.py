from PIL import Image

# Load PNG
img = Image.open("prism_logo.png")

# Convert to grayscale, then to 1-bit (black and white)
bw = img.convert("L").point(lambda x: 0 if x < 128 else 255, '1')

# Optionally resize (uncomment and adjust if needed)
# bw = bw.resize((300, int(bw.height * 300 / bw.width)), Image.LANCZOS)

# Save as BMP
bw.save("prism_logo_bw.bmp") 