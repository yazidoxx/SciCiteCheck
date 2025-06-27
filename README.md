# DataRefInspector

**Dataset Citation Status Verification Tool**

A comprehensive toolkit for verifying the accessibility and citation status of scientific datasets across multiple biological and scientific repositories. DataRefInspector helps researchers and data scientists validate dataset citations in scientific publications by checking their public availability and extracting metadata from various data repositories.

## 🎯 Overview

DataRefInspector addresses the critical need for verifying dataset citations in scientific literature. It provides automated tools to check whether cited datasets are publicly accessible, retrieve file information, and validate repository links across major scientific databases.

### Key Features

- **Multi-Repository Support**: Covers 15+ major scientific data repositories
- **Accessibility Verification**: Checks if datasets are publicly accessible or restricted
- **Metadata Extraction**: Retrieves file listings, sizes, and modification dates
- **Citation Validation**: Validates dataset accession numbers and repository links
- **API Integration**: Provides programmatic access via REST API endpoints
- **Cross-Platform**: Works with Python environment

## 🗄️ Supported Repositories

### Biological & Genomic Data
- **NCBI Repositories**
  - GenBank
  - SRA (Sequence Read Archive)
  - BioProject
  - ClinVar
- **EBI Repositories**
  - ArrayExpress
  - ENA (European Nucleotide Archive)
  - EGA (European Genome-phenome Archive)
- **Specialized Databases**
  - GEO (Gene Expression Omnibus)
  - PDB (Protein Data Bank)
  - EMDB (Electron Microscopy Data Bank)
  - GWAS Catalog

### Proteomics & Mass Spectrometry
- **PRIDE** (proteomics data)
- **MassIVE** (mass spectrometry data)

### General Research Data
- **Zenodo** (research data repository)
- **OSF** (Open Science Framework)
- **ENCODE** (genomics data)

## 🛠️ Installation

### Prerequisites

- **Python** (>= 3.9) with dependencies:
  ```bash
  pip install requests beautifulsoup4 lxml typing-extensions
  ```

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/SciCiteCheck.git
   cd SciCiteCheck
   ```

2. **Set up Python virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt  # If available
   ```


## 🚀 Usage

### Python API Classes

Use the specialized Python classes for advanced functionality:

```python
from src.repo_scripts.gwas_api import GWASClient
from src.repo_scripts.zenodo_api import ZenodoClient
from src.repo_scripts.osf_api import OSFClient

# GWAS Catalog
gwas = GWASClient()
result = gwas.process_accession("GCST90027158")
print(f"Access: {result['access']}")
print(f"Files: {result['files']}")

# Zenodo
zenodo = ZenodoClient()
zenodo_result = zenodo.get_record_info("1234567")

# OSF
osf = OSFClient()
osf_result = osf.get_project_info("abc123")
```

## 🏗️ Architecture

```
SciCiteCheck/
├── src/repo_scripts/           # Python-based API clients
│   ├── gwas_api.py            # GWAS Catalog client
│   ├── zenodo_api.py          # Zenodo client
│   ├── osf_api.py             # OSF client
│   ├── utils.py               # Shared utilities
│   └── ...                    # Other API clients
└── venv/                      # Python virtual environment
```

## 📈 Performance Considerations

- **Caching**: HTTP responses are cached to reduce API calls
- **Rate Limiting**: Built-in delays prevent overwhelming servers
- **Timeout Handling**: Configurable timeouts for slow repositories
- **Batch Processing**: Efficient handling of multiple accessions
- **Error Recovery**: Graceful handling of network failures

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Install development dependencies
4. Run tests before committing
5. Submit a pull request

### Adding New Repositories

To add support for a new repository:

1. **R Implementation**: Create `new_repo_data_rep.R` in `retrieve_data_from_repo/`
2. **Python Implementation**: Create `new_repo_api.py` in `src/repo_scripts/`
3. **Follow the standard API pattern**:
   ```r
   new_repo_process_accession <- function(acc_no) {
     list(
       access = "public|restricted|error",
       files = list_of_files_or_datasets
     )
   }
   ```
## 📜 License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See the [LICENSE](LICENSE) file for details.

The AGPL-3.0 license ensures that:
- The software remains free and open source
- Any modifications must be shared under the same license
- Network use of the software requires source code availability


## 🆘 Support & Documentation

- **Issues**: Report bugs and request features on [GitHub Issues](https://github.com/yourusername/SciCiteCheck/issues)
- **Discussions**: Join community discussions on [GitHub Discussions](https://github.com/yourusername/SciCiteCheck/discussions)

## 🔮 Roadmap

### Upcoming Features

- **Web Interface**: Browser-based GUI for non-programmers
- **Citation Analysis**: Integration with bibliography management tools
- **Machine Learning**: Automated citation quality assessment
- **Export Formats**: Support for CSV, Excel, and JSON exports

### Repository Additions

- **Figshare**: Research data and figures
- **Dryad**: Data underlying scientific publications
- **Harvard Dataverse**: Social science research data
- **PANGAEA**: Earth and environmental science data
- **ImmPort**: Immunology research data

---

**Made with ❤️ for the scientific community**
*Ensuring reproducible research through reliable data citation verification*
