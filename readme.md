# SqlLedger-WooCommerce-Integration

## Description

WooCommerce Integration for SQL-Ledger. Extremely simple to implement, no special plugin required.

This script works by leveraging the WooCommerce webhooks to add any new orders directly into SQL-Ledger. Users are given an option to either add new orders as an order or as an invoice. Item is checked if it exists based on SKU and ItemID; if not, it gets added to SQL-Ledger. Customer is also checked for based on Phone Number & Email; it not, gets added to Sql-Ledger.

## Implementation Guide

### 1. **Downloading the Repo Folder**:

- Download the repository folder.
- Place the downloaded repo folder into any standard SQL-Ledger installation.

### 2. **Setting Up WooCommerce Webhooks**:

- Go to `WooCommerce > Settings > Advance > Webhooks` in your WordPress dashboard.
- Add a new webhook.
- Set the topic to "Order Created".
- Set the API Version to V3.
- Add the delivery URL as `yourledgerurl/woocommerce/order.pl`.

### 3. **Configuring the WooCommerce Snippet**:

- Copy the provided snippet from `woo.php`.
- Modify the following variables in the snippet:
  - `DBname`: Set this to the database name from SQL-Ledger that you wish to integrate with.
  - `create_invoice`: If set to `true`, this will create an invoice directly. If set to `false`, it will create an order.
- Add the modified snippet to your WordPress site. This can be done by:
  - Adding it to your theme's `functions.php` file.
  - OR using a custom script plugin. I recommend using the [Code Snippets](https://wordpress.org/plugins/code-snippets/) plugin.
