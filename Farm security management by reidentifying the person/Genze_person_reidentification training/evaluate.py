import os
import pickle
import time
import torch
import numpy as np
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, classification_report, roc_curve, auc
from facenet_pytorch import InceptionResnetV1

class SimpleDataset(Dataset):
    def __init__(self, image_paths, labels, transform=None):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        img_path = self.image_paths[idx]
        label = self.labels[idx]
        img = Image.open(img_path).convert('RGB')
        if self.transform:
            img = self.transform(img)
        return img, label

def compute_similarities(embeddings, labels, templates, idx_to_class):
    pos_sims = []
    neg_sims = []
    
    for emb, label in zip(embeddings, labels):
        cls_name = idx_to_class[label]
        for t_name, t_emb in templates.items():
            sim = np.dot(emb, t_emb) # Cosine similarity since both are L2-normalized
            if t_name == cls_name:
                pos_sims.append(sim)
            else:
                neg_sims.append(sim)
                
    return np.array(pos_sims), np.array(neg_sims)

def tune_threshold(pos_sims, neg_sims):
    thresholds = np.linspace(0.0, 1.0, 500)
    far_list, frr_list = [], []
    f1_list = []
    
    best_f1 = -1
    best_th_f1 = 0.5
    eer_th = 0.5
    min_diff = 1e9
    
    for th in thresholds:
        # FAR: False Acceptance Rate = ratio of negative pairs accepted as match
        far = np.mean(neg_sims >= th)
        # FRR: False Rejection Rate = ratio of positive pairs rejected as match
        frr = np.mean(pos_sims < th)
        
        far_list.append(far)
        frr_list.append(frr)
        
        # Calculate F1 Score on verification
        tp = np.sum(pos_sims >= th)
        fp = np.sum(neg_sims >= th)
        fn = np.sum(pos_sims < th)
        
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0
        f1_list.append(f1)
        
        if f1 > best_f1:
            best_f1 = f1
            best_th_f1 = th
            
        diff = abs(far - frr)
        if diff < min_diff:
            min_diff = diff
            eer_th = th
            
    return thresholds, np.array(far_list), np.array(frr_list), np.array(f1_list), eer_th, best_th_f1

def main():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # 1. Load splits and database
    splits_path = 'dataset_splits.pth'
    db_path = 'embeddings_db.pkl'
    checkpoint_path = 'best_checkpoint.pth'
    
    if not os.path.exists(splits_path) or not os.path.exists(db_path):
        print("Error: Missing dataset_splits.pth or embeddings_db.pkl. Please run train.py and database.py first.")
        return
        
    splits = torch.load(splits_path)
    val_paths, val_labels = splits['val_data']
    test_paths, test_labels = splits['test_data']
    class_to_idx = splits['class_to_idx']
    idx_to_class = {v: k for k, v in class_to_idx.items()}
    
    with open(db_path, 'rb') as f:
        db = pickle.load(f)
    templates = db['templates']
    
    # 2. Load model
    backbone = InceptionResnetV1(pretrained='vggface2').eval()
    if os.path.exists(checkpoint_path):
        checkpoint = torch.load(checkpoint_path, map_location=device)
        backbone.load_state_dict(checkpoint['backbone_state_dict'])
    backbone = backbone.to(device)
    
    # Preprocessing transform
    facenet_norm = transforms.Compose([
        transforms.ToTensor(),
        transforms.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0)
    ])
    
    # 3. Process Validation Set and Tune Threshold
    val_dataset = SimpleDataset(val_paths, val_labels, transform=facenet_norm)
    val_loader = DataLoader(val_dataset, batch_size=32, shuffle=False)
    
    val_embs, val_lbls = [], []
    with torch.no_grad():
        for images, labels in val_loader:
            images = images.to(device)
            feats = backbone(images)
            # L2-normalize features
            feats = feats / torch.norm(feats, p=2, dim=1, keepdim=True)
            val_embs.extend(feats.cpu().numpy())
            val_lbls.extend(labels.numpy())
            
    val_embs = np.array(val_embs)
    val_lbls = np.array(val_lbls)
    
    pos_sims, neg_sims = compute_similarities(val_embs, val_lbls, templates, idx_to_class)
    thresholds, far, frr, f1_scores, eer_th, best_th_f1 = tune_threshold(pos_sims, neg_sims)
    
    print("--- Threshold Tuning on Validation Set ---")
    print(f"Equal Error Rate (EER) Threshold: {eer_th:.4f} (FAR = {far[np.argmin(np.abs(thresholds - eer_th))]*100:.2f}%, FRR = {frr[np.argmin(np.abs(thresholds - eer_th))]*100:.2f}%)")
    print(f"Best F1-Score Threshold:         {best_th_f1:.4f} (F1 = {f1_scores[np.argmin(np.abs(thresholds - best_th_f1))]*100:.2f}%)")
    
    # Use Best F1-Score Threshold
    tuned_threshold = best_th_f1
    
    # Save tuned threshold back to database
    db['threshold'] = tuned_threshold
    with open(db_path, 'wb') as f:
        pickle.dump(db, f)
    print(f"Saved tuned threshold {tuned_threshold:.4f} to {db_path}")
    
    # Save curves plot
    plt.figure(figsize=(12, 5))
    plt.subplot(1, 2, 1)
    plt.plot(thresholds, far, label='False Acceptance Rate (FAR)')
    plt.plot(thresholds, frr, label='False Rejection Rate (FRR)')
    plt.axvline(x=tuned_threshold, color='r', linestyle='--', label=f'Tuned Threshold ({tuned_threshold:.2f})')
    plt.xlabel('Cosine Similarity Threshold')
    plt.ylabel('Rate')
    plt.title('FAR and FRR Curves')
    plt.legend()
    
    plt.subplot(1, 2, 2)
    # Compute ROC Curve
    # True Accept Rate (TAR) = 1 - FRR
    tar = 1.0 - frr
    plt.plot(far, tar, label=f'ROC Curve (AUC = {auc(far, tar):.4f})')
    plt.xlabel('False Acceptance Rate (FAR)')
    plt.ylabel('True Acceptance Rate (TAR)')
    plt.title('ROC Curve (TAR vs FAR)')
    plt.legend()
    plt.tight_layout()
    plt.savefig('threshold_tuning.png')
    print("Tuning curves saved to threshold_tuning.png\n")
    
    # 4. Evaluate Test Set
    test_dataset = SimpleDataset(test_paths, test_labels, transform=facenet_norm)
    test_loader = DataLoader(test_dataset, batch_size=1, shuffle=False) # Batch size 1 to measure single inference time
    
    print("--- Evaluating Test Set ---")
    y_true = []
    y_pred = []
    y_pred_with_unknown = []
    similarities = []
    
    inference_times = []
    
    with torch.no_grad():
        for images, labels in test_loader:
            images = images.to(device)
            
            # Start timer
            start_time = time.perf_counter()
            
            feats = backbone(images)
            # L2-normalize
            feats = feats / torch.norm(feats, p=2, dim=1, keepdim=True)
            feat = feats[0].cpu().numpy()
            
            # Match against database templates
            best_sim = -1.0
            best_match = "Unknown"
            
            for t_name, t_emb in templates.items():
                sim = np.dot(feat, t_emb)
                if sim > best_sim:
                    best_sim = sim
                    best_match = t_name
            
            # Stop timer
            end_time = time.perf_counter()
            inference_times.append((end_time - start_time) * 1000.0) # in ms
            
            true_class = idx_to_class[labels[0].item()]
            y_true.append(true_class)
            y_pred.append(best_match)
            similarities.append(best_sim)
            
            # Handle Unknown detection
            if best_sim >= tuned_threshold:
                y_pred_with_unknown.append(best_match)
            else:
                y_pred_with_unknown.append("Unknown")
                
    # 5. Report Metrics
    avg_inference_time = np.mean(inference_times)
    fps = 1000.0 / avg_inference_time
    
    # Closed-set Accuracy (nearest database neighbor)
    closed_set_acc = np.mean(np.array(y_true) == np.array(y_pred))
    
    # Open-set Accuracy (including Unknown option)
    open_set_acc = np.mean(np.array(y_true) == np.array(y_pred_with_unknown))
    
    print(f"Closed-Set Rank-1 Accuracy: {closed_set_acc * 100:.2f}%")
    print(f"Open-Set Accuracy (with threshold {tuned_threshold:.2f}): {open_set_acc * 100:.2f}%")
    print(f"Average Inference Time per face: {avg_inference_time:.2f} ms ({fps:.1f} FPS)")
    
    print("\nClassification Report (Open-set with 'Unknown' class):")
    # All classes in dataset plus 'Unknown'
    labels_list = sorted(list(class_to_idx.keys()))
    print(classification_report(y_true, y_pred_with_unknown, labels=labels_list, zero_division=0))
    
    # FAR / FRR on Test Set
    test_lbls_arr = np.array([class_to_idx[y] for y in y_true])
    test_embs_arr = []
    # Extract test embeddings for similarity analysis
    with torch.no_grad():
        for images, _ in DataLoader(test_dataset, batch_size=32):
            images = images.to(device)
            feats = backbone(images)
            feats = feats / torch.norm(feats, p=2, dim=1, keepdim=True)
            test_embs_arr.extend(feats.cpu().numpy())
    test_embs_arr = np.array(test_embs_arr)
    
    test_pos_sims, test_neg_sims = compute_similarities(test_embs_arr, test_lbls_arr, templates, idx_to_class)
    test_far = np.mean(test_neg_sims >= tuned_threshold)
    test_frr = np.mean(test_pos_sims < tuned_threshold)
    
    print(f"Test Set False Acceptance Rate (FAR): {test_far * 100:.2f}%")
    print(f"Test Set False Rejection Rate (FRR):  {test_frr * 100:.2f}%")
    
    # Confusion Matrix
    print("\nConfusion Matrix (Open-set):")
    all_classes = labels_list + ["Unknown"]
    cm = confusion_matrix(y_true, y_pred_with_unknown, labels=all_classes)
    
    # Print clean matrix
    header = f"{'True/Pred':<12}" + "".join([f"{c:<10}" for c in all_classes])
    print(header)
    print("-" * len(header))
    for i, row in enumerate(cm):
        row_str = f"{all_classes[i]:<12}" + "".join([f"{val:<10}" for val in row])
        print(row_str)

if __name__ == "__main__":
    main()
