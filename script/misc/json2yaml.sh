# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

# Assign the filename from the command line argument
name="$1"

# Check if the input JSON file exists
json_file="config/${name}.json"

# Generate the YAML file path dynamically
yaml_file="config/${name}.yaml"

# Use yq to convert JSON to YAML
yq eval -o yaml "$json_file" >"$yaml_file"
