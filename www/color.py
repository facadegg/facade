from PIL import Image

# Load the image
image = Image.open('/Users/shukantpal/Desktop/test.png')

(x, y) = (0, 0)

# Get the pixel value at a specific coordinate
pixel_value = image.getpixel((x, y))

print(pixel_value)

# Separate the RGB channels (if applicable)
red, green, blue, alpha = pixel_value

# Print the pixel value or do further processing
print(f"Pixel value at ({x}, {y}): R={red}, G={green}, B={blue}")

hex_value = '#{:02x}{:02x}{:02x}'.format(39, 41, 43)
print(hex_value)
