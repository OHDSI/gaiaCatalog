FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the "data" directory to the working directory in the container
COPY data /app/data

EXPOSE 7860

# Make client1.py executable
ENV GRADIO_SERVER_NAME="0.0.0.0" 

# Run client1.py when the container launches
CMD ["python", "client.py"]
