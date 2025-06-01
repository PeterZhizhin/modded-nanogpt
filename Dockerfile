FROM vastai/pytorch:cuda-12.8.1-auto


COPY cursor-server.zip /cursor-server.zip

RUN . /venv/main/bin/activate && \
    python -m pip install numpy tqdm huggingface-hub && \
    pip install --pre --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

CMD ["bash"]
ENTRYPOINT []
