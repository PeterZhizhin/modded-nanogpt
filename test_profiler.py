import torch
import torch.nn as nn
import torch.optim as optim
from torch.profiler import profile, record_function, ProfilerActivity

# Initialize CUDA and CUPTI
torch.cuda.init()
torch.cuda.synchronize()

# Create a simple model
class SimpleModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.linear1 = nn.Linear(1000, 1000)
        self.linear2 = nn.Linear(1000, 1000)
        self.linear3 = nn.Linear(1000, 1000)
    
    def forward(self, x):
        x = torch.relu(self.linear1(x))
        x = torch.relu(self.linear2(x))
        x = self.linear3(x)
        return x

# Initialize model and optimizer
model = SimpleModel().cuda()
optimizer = optim.Adam(model.parameters())

# Create some dummy data
x = torch.randn(32, 1000).cuda()
y = torch.randn(32, 1000).cuda()

# Warm up CUDA
for _ in range(3):
    output = model(x)
    loss = torch.nn.functional.mse_loss(output, y)
    loss.backward()
    optimizer.step()
    optimizer.zero_grad()
torch.cuda.synchronize()

# Training loop with profiling
with profile(
    activities=[
        # ProfilerActivity.CPU,
        ProfilerActivity.CUDA,
    ],
    schedule=torch.profiler.schedule(
        wait=1,
        warmup=1,
        active=2,
        repeat=1
    ),
    on_trace_ready=torch.profiler.tensorboard_trace_handler("./log/profiler_test"),
    record_shapes=True,
    profile_memory=True,
    with_stack=True
) as prof:
    for step in range(10):
        # Forward pass
        with record_function("forward"):
            output = model(x)
            loss = torch.nn.functional.mse_loss(output, y)
        
        # Backward pass
        with record_function("backward"):
            loss.backward()
            optimizer.step()
            optimizer.zero_grad()
        
        # Print loss
        if step % 2 == 0:
            print(f"Step {step}, Loss: {loss.item():.4f}")
        
        # Send a signal to the profiler that the next iteration has started
        prof.step()

# Print profiling results
print(prof.key_averages().table(
    sort_by="self_cuda_time_total", row_limit=10)) 