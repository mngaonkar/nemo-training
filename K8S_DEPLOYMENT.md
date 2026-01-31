# NeMo Training on Kubernetes

## Prerequisites
- Kubernetes cluster with GPU nodes
- `kubectl` configured to access your cluster
- GPU operator installed on your cluster (for NVIDIA GPU support)

## Deployment Steps

### 1. Create a ConfigMap with the training script

```bash
kubectl create configmap nemo-training-script \
  --from-file=simple-train-script.py=simple-train-script-k8s.py
```

### 2. Create the PersistentVolumeClaim

```bash
kubectl apply -f k8s-pvc.yaml
```

Verify the PVC is created:
```bash
kubectl get pvc nemo-training-pvc
```

### 3. Deploy the training job

```bash
kubectl apply -f k8s-job.yaml
```

### 4. Monitor the training

Check job status:
```bash
kubectl get jobs
```

View pod logs (streaming):
```bash
kubectl logs -f job/nemo-training-job
```

Get pod name and check details:
```bash
kubectl get pods -l app=nemo-training
kubectl describe pod <pod-name>
```

### 5. Access the saved checkpoints

Once training completes, you can access the checkpoints in several ways:

#### Option A: Copy from the PVC to local machine
```bash
# Create a temporary pod with the PVC mounted
kubectl run -it --rm checkpoint-viewer \
  --image=busybox \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "checkpoint-viewer",
      "image": "busybox",
      "command": ["sh"],
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "checkpoints",
        "mountPath": "/checkpoints"
      }]
    }],
    "volumes": [{
      "name": "checkpoints",
      "persistentVolumeClaim": {
        "claimName": "nemo-training-pvc"
      }
    }]
  }
}'

# Then from another terminal, copy files out:
kubectl cp <pod-name>:/checkpoints ./local-checkpoints
```

#### Option B: Mount PVC to another pod for inference
Create a new pod/deployment that mounts the same PVC to use the checkpoints.

#### Option C: Use kubectl cp directly from the job pod
```bash
# Get the pod name
POD_NAME=$(kubectl get pods -l app=nemo-training -o jsonpath='{.items[0].metadata.name}')

# Copy checkpoints to local
kubectl cp ${POD_NAME}:/workspace/checkpoints ./local-checkpoints
```

## Customization

### Adjust GPU count
Edit `k8s-job.yaml` and change:
```yaml
nvidia.com/gpu: 1  # Change to desired number
```

Also update `simple-train-script-k8s.py`:
```python
devices=1,  # Match the GPU count
```

### Adjust storage size
Edit `k8s-pvc.yaml`:
```yaml
storage: 100Gi  # Adjust as needed
```

### Multi-node training (optional)
For multi-node training, replace the Job with a PyTorchJob or use MPI:
- Install the Training Operator: https://github.com/kubeflow/training-operator
- Use PyTorchJob CRD for distributed training

### Change storage class
If your cluster has specific storage classes:
```yaml
storageClassName: fast-ssd  # Use your cluster's storage class
```

## Cleanup

Delete the job:
```bash
kubectl delete job nemo-training-job
```

Delete the ConfigMap:
```bash
kubectl delete configmap nemo-training-script
```

Keep the PVC if you want to retain checkpoints, or delete it:
```bash
kubectl delete pvc nemo-training-pvc
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod <pod-name>
kubectl get events --sort-by='.lastTimestamp'
```

### GPU not available
Check GPU resources:
```bash
kubectl describe nodes | grep -A 5 "nvidia.com/gpu"
```

### PVC binding issues
```bash
kubectl get pv
kubectl describe pvc nemo-training-pvc
```

### Training errors
Check logs:
```bash
kubectl logs <pod-name>
```
