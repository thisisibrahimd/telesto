 
# Define variables
containers_file := "deploy/.containers"
kind_cluster_name := "main-telesto-cluster"

# Load images from the .containers file into the kind cluster
load-images:
    if [ -f "{{containers_file}}" ]; then \
        while IFS= read -r image; do \
            echo "Loading image: $image"; \
            tar_file=$(echo "$image" | tr '/:' '__'); \
            podman image save "$image" -o "deploy/$tar_file.tar" && \
            kind load image-archive --name "{{kind_cluster_name}}" "deploy/$tar_file.tar"; \
            rm "deploy/$tar_file.tar"; \
        done < "{{containers_file}}"; \
    else \
        echo "File {{containers_file}} not found."; \
    fi

