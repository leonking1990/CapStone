import requests

# Replace with your server's IP and port
url = "http://35.239.234.106:8000/predict"

# Replace with the path to your image file
image_path = "assets/Apple_Healthy.JPG"


# Prepare and send the request
with open(image_path, "rb") as img_file:
    files = {"file": img_file}
    response = requests.post(url, files=files)

# Print the response
print("Status Code:", response.status_code)
print("Response:", response.json())
