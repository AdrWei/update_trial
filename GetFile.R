name: Google Sheets Update

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'

      - name: Install Python dependencies
        run: |
          pip install pandas gspread oauth2client rpy2

      - name: Set up R
        uses: r-lib/actions/setup-r@v2
        with:
          r-version: '4.2.0'

      - name: Verify R installation
        run: |
          R --version
          which R

      - name: Install R dependencies
        run: |
          R -e 'install.packages(c("dplyr", "ggplot2"))'

      - name: Create credentials file
        run: echo '${{ secrets.GOOGLE_CREDENTIALS_JSON }}' > credentials.json

      - name: Run Python script
        env:
          SHEET_ID: ${{ secrets.SHEET_ID }}
        run: python your_script_name.py

      - name: Remove credentials file
        run: rm credentials.json
