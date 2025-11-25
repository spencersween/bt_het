#' Bradley-Terry neural network module
#'
#' Up to 3 layer MLP for lambda(x)
#'
#' @export
bt_net = nn_module(
  "bt_net",
  
  initialize = function(p,
                        k_minus_1,
                        hidden        = integer(),
                        dropout       = 0.0,
                        use_batchnorm = FALSE) {
    
    self$n_hidden      = length(hidden)
    self$use_batchnorm = use_batchnorm
    
    if (self$n_hidden > 3) {
      stop("hidden can have at most 3 layers. Got length(hidden) = ", self$n_hidden)
    }
    
    if (self$n_hidden > 0) {
      dropout_vec = rep_len(dropout, self$n_hidden)
    } else {
      dropout_vec = numeric()
    }
    self$dropout_vec = dropout_vec
    
    in_dim = p
    
    if (self$n_hidden >= 1) {
      self$fc1 = nn_linear(in_dim, hidden[1])
      if (use_batchnorm) {
        self$bn1 = nn_batch_norm1d(num_features = hidden[1])
      }
      self$drop1 = nn_dropout(p = dropout_vec[1])
      in_dim = hidden[1]
      
      nn_init_kaiming_uniform_(self$fc1$weight, nonlinearity = "relu")
      nn_init_constant_(self$fc1$bias, 0)
      if (use_batchnorm) {
        nn_init_constant_(self$bn1$weight, 1)
        nn_init_constant_(self$bn1$bias, 0)
      }
    }
    
    if (self$n_hidden >= 2) {
      self$fc2 = nn_linear(in_dim, hidden[2])
      if (use_batchnorm) {
        self$bn2 = nn_batch_norm1d(num_features = hidden[2])
      }
      self$drop2 = nn_dropout(p = dropout_vec[2])
      in_dim = hidden[2]
      
      nn_init_kaiming_uniform_(self$fc2$weight, nonlinearity = "relu")
      nn_init_constant_(self$fc2$bias, 0)
      if (use_batchnorm) {
        nn_init_constant_(self$bn2$weight, 1)
        nn_init_constant_(self$bn2$bias, 0)
      }
    }
    
    if (self$n_hidden >= 3) {
      self$fc3 = nn_linear(in_dim, hidden[3])
      if (use_batchnorm) {
        self$bn3 = nn_batch_norm1d(num_features = hidden[3])
      }
      self$drop3 = nn_dropout(p = dropout_vec[3])
      in_dim = hidden[3]
      
      nn_init_kaiming_uniform_(self$fc3$weight, nonlinearity = "relu")
      nn_init_constant_(self$fc3$bias, 0)
      if (use_batchnorm) {
        nn_init_constant_(self$bn3$weight, 1)
        nn_init_constant_(self$bn3$bias, 0)
      }
    }
    
    self$head = nn_linear(in_dim, k_minus_1)
    nn_init_xavier_uniform_(self$head$weight)
    nn_init_constant_(self$head$bias, 0)
  },
  
  forward = function(x) {
    h = x
    
    if (self$n_hidden >= 1) {
      h = self$fc1(h)
      if (self$use_batchnorm) {
        h = self$bn1(h)
      }
      h = h$relu()
      h = self$drop1(h)
    }
    
    if (self$n_hidden >= 2) {
      h = self$fc2(h)
      if (self$use_batchnorm) {
        h = self$bn2(h)
      }
      h = h$relu()
      h = self$drop2(h)
    }
    
    if (self$n_hidden >= 3) {
      h = self$fc3(h)
      if (self$use_batchnorm) {
        h = self$bn3(h)
      }
      h = h$relu()
      h = self$drop3(h)
    }
    
    self$head(h)
  }
)

