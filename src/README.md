# Create Samples App

This project is a Python Flask application that utilizes Azure Open AI Services to generate FRP (Flexible Response Protocol) sample documents.

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Functionality](#functionality)
- [Contributing](#contributing)
- [License](#license)

## Installation

To set up the project, clone the repository and install the required dependencies:

``` Bash 
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Usage

To run the application, execute the following command:

```bash
python src/main.py
```

Make sure to configure your Azure Open AI Services credentials in the environment before running the application.

## Functionality

The application connects to Azure Open AI Services to generate FRP sample documents. It includes utility functions for formatting and processing the generated documents, ensuring that the output meets the required specifications.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.