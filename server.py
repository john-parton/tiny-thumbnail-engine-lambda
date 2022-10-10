from tiny_thumbnail_engine.server.aws import lambda_handler  # noqa

# Example Dockerfile to build thumbnail engine for lambda

FROM tiny-thumbnail-engine-base:latest

RUN pip install tiny-thumbnail-engine[server] --upgrade

COPY requirements.txt .
RUN pip install wheel && pip install -r requirements.txt

COPY tiny_thumbnail_engine ${LAMBDA_TASK_ROOT}/tiny_thumbnail_engine/

CMD ["tiny_thumbnail_engine.server.aws.lambda_handler"]
