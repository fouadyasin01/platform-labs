FROM python:3.12-alpine

WORKDIR /app

COPY rest-api/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY rest-api/src ./src

EXPOSE 3001

CMD ["python", "src/app.py"]
