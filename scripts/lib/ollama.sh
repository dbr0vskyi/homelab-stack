#!/bin/bash

# Ollama model management

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

setup_ollama_models() {
    log_info "Setting up Ollama models..."
    
    wait_for_ollama
    download_models
    
    log_success "Ollama models setup complete"
}

wait_for_ollama() {
    log_info "Waiting for Ollama to be ready..."
    sleep 30
}

download_models() {
    if [[ -f "config/ollama/models.txt" ]]; then
        download_models_from_file
    else
        download_default_models
    fi
}

download_models_from_file() {
    while IFS= read -r model; do
        # Skip comments and empty lines
        [[ "$model" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${model// }" ]] && continue
        
        download_model "$model"
    done < config/ollama/models.txt
}

download_default_models() {
    log_info "Downloading optimized models for Pi 5 16GB..."
    download_model "llama3.1:8b"
    download_model "qwen2.5:7b" 
    download_model "qwen2.5:14b"
}

download_model() {
    local model="$1"
    log_info "Downloading model: $model"
    
    if ! docker exec homelab-ollama ollama pull "$model"; then
        log_warning "Failed to download $model"
    fi
}

# List currently installed Ollama models
list_ollama_models() {
    log_info "Available Ollama models:"
    if ! docker ps --format "{{.Names}}" | grep -q "^homelab-ollama$"; then
        log_error "Ollama container is not running"
        return 1
    fi
    
    docker exec homelab-ollama ollama list 2>/dev/null || log_error "Failed to list models"
}

# Download a single Ollama model
download_ollama_model() {
    local model="$1"
    
    if [[ -z "$model" ]]; then
        log_error "Model name is required"
        return 1
    fi
    
    if ! docker ps --format "{{.Names}}" | grep -q "^homelab-ollama$"; then
        log_error "Ollama container is not running"
        return 1
    fi
    
    download_model "$model"
}

# Restore models from a backup list
restore_models_from_backup() {
    local models_file="$1"
    
    if [[ -z "$models_file" || ! -f "$models_file" ]]; then
        log_error "Valid models file is required"
        return 1
    fi
    
    log_info "Restoring Ollama models from backup list..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^homelab-ollama$"; then
        log_error "Ollama container is not running"
        return 1
    fi
    
    local model_count=0
    while IFS= read -r model; do
        # Skip comments and empty lines
        [[ "$model" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${model// }" ]] && continue
        
        log_info "Restoring model: $model"
        download_model "$model"
        ((model_count++))
    done < "$models_file"
    
    log_success "Restored $model_count models from backup"
}