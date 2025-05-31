import os

import torch
import torch.distributed as dist

print(f"Starting process with RANK={os.environ.get('RANK')}, WORLD_SIZE={os.environ.get('WORLD_SIZE')}, LOCAL_RANK={os.environ.get('LOCAL_RANK')}")

rank = int(os.environ["RANK"])
world_size = int(os.environ["WORLD_SIZE"])

assert torch.cuda.is_available()
device = torch.device("cuda", int(os.environ["LOCAL_RANK"]))
torch.cuda.set_device(device)
print(f"Process {rank}: Setting up device {device}")

try:
    print(f"Process {rank}: Initializing process group")
    dist.init_process_group(backend="nccl", world_size=world_size, rank=rank)
    print(f"Process {rank}: Process group initialized")

    print(f'Process {rank}: Starting all reduce')
    tensor = torch.rand(1).cuda()
    print(f"Process {rank}: Created tensor {tensor}")
    res = dist.all_reduce(tensor)
    print(f'Process {rank}: Post all reduce {res}')
    
    print(f'Process {rank}: At barrier')
    dist.barrier()
    print(f'Process {rank}: Past barrier')

finally:
    print(f"Process {rank}: Cleaning up")
    dist.destroy_process_group()
    print(f"Process {rank}: Cleanup complete")