# Configuration file for Heterogeneous Bradley-Terry model

# File paths
PATH_PARQUET = "~/Downloads/train-00000-of-00001-cced8514c7ed782a.parquet"
PATH_PROCESSED1 = "/Users/spencersween/Downloads/chatbot_processed.csv"
PATH_PROCESSED2 = "/Users/spencersween/Downloads/chatbot_processed2.csv"

# Output directories
DIR_RESULTS = "results"
DIR_PLOTS = "plots"

# Model configuration
BASE_MODEL = "gpt-4"
NFOLDS = 2
SEED = 123

# Neural network hyperparameters
HIDDEN_BT = rep(10, 3)
DROPOUT_BT = rep(0.1, 3)
USE_BATCHNORM_BT = FALSE

HIDDEN_H = rep(10, 3)
DROPOUT_H = rep(0.1, 3)
USE_BATCHNORM_H = FALSE

LR_BT = 1e-2
LR_H = 1e-2
WEIGHT_DECAY_BT = 1e-5
WEIGHT_DECAY_H = 1e-5

BATCH_SIZE_BT = 2^15
BATCH_SIZE_H = 2^15

MAX_EPOCHS_BT = 10
MAX_EPOCHS_H = 10

PATIENCE_BT = 10
PATIENCE_H = 10

HESS_RIDGE = 1e-5

# Device
DEVICE = "cpu"  # or "cuda" if available

