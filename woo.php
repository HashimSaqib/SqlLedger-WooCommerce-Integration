/**
 * Add SQL-Ledger fields to WooCommerce webhook payload.
 *
 * @param array  $payload The webhook payload.
 * @param string $resource The webhook resource (order).
 * @param string $resource_id The ID of the resource being affected.
 * @param int    $webhook_id The webhook ID.
 *
 * @return array Modified payload.
 */

function sql_ledger_fields( $payload, $resource, $resource_id, $webhook_id ) {

   
    $dbname = "ledgeri"; //SQL-Ledger Database Name Here
    $create_invoice = true; //Whether To Create An Order Or An Invoice

    $payload['sql-ledger'] = array(
        'dbname'         => $dbname,
        'create_invoice' => $create_invoice,
    );

    return $payload;
}

//Filter to make the webhook delivery instant.
apply_filters('woocommerce_webhook_deliver_async', function() {
  return false;
});

//Adding the WooCommerce Filter
add_filter( 'woocommerce_webhook_payload', 'sql_ledger_fields', 10, 4 );
