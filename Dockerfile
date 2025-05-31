FROM vastai/pytorch

RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install numpy tqdm huggingface-hub && \
    apt-get update && apt-get install -y git

CMD ["bash"]
ENTRYPOINT []
