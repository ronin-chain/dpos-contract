import json
import argparse


def order_json_keys(file_path):
    # Read the json data from the file
    with open(file_path, "r") as file:
        data = json.load(file)

    # Sort the data recursively
    def sort_dict(d):
        if isinstance(d, dict):
            return {k: sort_dict(v) for k, v in sorted(d.items())}
        return d

    ordered_data = sort_dict(data)

    # Write the ordered json back to the same file
    with open(file_path, "w") as file:
        json.dump(ordered_data, file)


if __name__ == "__main__":
    # Setup argument parser
    parser = argparse.ArgumentParser(
        description="Sort json file keys alphabetically and overwrite the file."
    )
    parser.add_argument("file_path", type=str, help="Path to the json file to sort")

    # Parse arguments
    args = parser.parse_args()

    # Run the function with the provided file path
    order_json_keys(args.file_path)
