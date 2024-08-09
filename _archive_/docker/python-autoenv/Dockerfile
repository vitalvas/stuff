ARG PYTHON_VERSION
FROM python:${PYTHON_VERSION}-alpine

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/app/main.py"]
