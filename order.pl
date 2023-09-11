#!/usr/bin/env perl

use Mojolicious::Lite;
use Mojo::UserAgent;
use DBI;
use DBIx::Simple;
use Data::Dumper;

# Helper To Create DB Handle
helper get_db_handle => sub {
    my ( $c, $dbname ) = @_;

    # Database connection using DBI
    my $dbh = DBI->connect( "dbi:Pg:dbname=$dbname", 'postgres', '',
        { AutoCommit => 1, RaiseError => 1 } );

    # Create and return a DBIx::Simple handle
    return DBIx::Simple->connect($dbh);
};

#Mojo User Agent
my $ua = Mojo::UserAgent->new;

get '/' => sub {
    my $c = shift;
    $c->render( text => "Working" );
};

post '/' => sub {
    my $c    = shift;
    my $data = $c->req->json;
    $c->app->log->debug( Dumper( ${data} ) );

    #Returning 200 For the Initial Webhook. To be changed to check for API key.
    if ( !$data->{'sql-ledger'} ) {
        return $c->render( status => 200 );
    }

    my $dbname     = $data->{'sql-ledger'}->{'dbname'};
    my $create_inv = $data->{'sql-ledger'}->{'create_invoice'};
    my $db         = $c->get_db_handle($dbname);

    # Check if order already exists
    my $order_exists =
      $db->query( "SELECT id FROM oe WHERE ordnumber = ?", $data->{id} )->list;
    if ($order_exists) {
        return $c->render( status => 409, text => "Order already exists!" );
    }

    #Department & Warehouse needed for for AR
    my $department_id = $db->query("SELECT id FROM department LIMIT 1")->list;
    my $warehouse_id  = $db->query("SELECT id FROM warehouse LIMIT 1")->list;

    my $order = {
        name     => $data->{id},
        customer => {
            name => $data->{billing}->{first_name} . ' '
              . $data->{billing}->{last_name},
            contact        => $data->{billing}->{first_name},
            phone          => $data->{billing}->{phone},
            email          => $data->{email}->{email},
            notes          => $data->{customer_note},
            terms          => 1,
            taxincluded    => 0,
            customernumber => $data->{customer_id},
            curr           => $data->{currency},
        },
        contact => {
            firstname     => $data->{billing}->{first_name},
            lastname      => $data->{billing}->{last_name},
            contacttitle  => '',
            occupation    => '',
            phone         => '',
            fax           => '',
            mobile        => '',
            email         => '',
            typeofcontact => 'company'
        },
        address => {
            address1 => $data->{billing}->{address_1},
            address2 => $data->{billing}->{address_2},
            city     => $data->{billing}->{city},
            state    => $data->{billing}->{state},
            zipcode  => $data->{billing}->{postcode},
            country  => $data->{billing}->{country},
        },
        shipto => {
            trans_id       => 0,
            shiptoname     => $data->{shipping}->{first_name},
            shiptoaddress1 => $data->{shipping}->{address_1},
            shiptoaddress2 => $data->{shipping}->{address_2},
            shiptocity     => $data->{shipping}->{city},
            shiptostate    => $data->{shipping}->{state},
            shiptozipcode  => $data->{shipping}->{postcode},
            shiptocountry  => $data->{shipping}->{country},
            shiptocontact  => $data->{shipping}->{first_name},
            shiptophone    => $data->{shipping}->{phone},
            shiptoemail    => $data->{shipping}->{email},
        },
        oe => {
            ordnumber     => $data->{id},
            transdate     => $data->{date_created_gmt},
            amount        => $data->{total},
            netamount     => $data->{subtotal},
            reqdate       => $data->{date_created_gmt},
            taxincluded   => $data->{prices_include_tax},
            shippingpoint => '',
            notes         => $data->{customer_note},
            curr          => $data->{currency},
            employee_id   => 1,
            closed        => 0,
            quotation     => 0,
            quonumber     => '',
            intnotes      => '',
            department_id => 1,
            shipvia       => '',
            language_code => '',
            ponumber      => '',
            terms         => 1,
            waybill       => '',
            warehouse_id  => 1,
            description   => '',
            exchangerate  => 1.0,
        },
        ar => {
            invnumber     => $data->{id},
            ordnumber     => $data->{id},
            transdate     => $data->{date_created_gmt},
            amount        => $data->{total},
            netamount     => $data->{total},
            shippingpoint => '',
            notes         => $data->{customer_note},
            intnotes      => $data->{customer_note},
            curr          => $data->{currency},
            employee_id   => 1,
            intnotes      => '',
            department_id => $department_id,
            shipvia       => '',
            language_code => '',
            terms         => 1,
            waybill       => '',
            warehouse_id  => $warehouse_id,
            description   => '',
            exchangerate  => 1.0,
            invoice       => '1',
            paid          => 0,
        }
    };

    my %defaults = $db->query("SELECT fldname, fldvalue FROM defaults")->map;

    # Create the order item hashrefs and add them to the order items arrayref
    foreach my $item_hash ( @{ $data->{line_items} } ) {
        my $parts_id = $db->query(
            "SELECT id FROM parts WHERE partnumber = ?",
            $item_hash->{sku} || $item_hash->{product_id}
        )->list;
        if ( !$parts_id ) {
            my $part = {
                partnumber  => $item_hash->{sku} || $item_hash->{product_id},
                description => $item_hash->{name},
                sellprice   => $item_hash->{price},
                unit        => 'each',
            };
            for (qw(inventory_accno_id expense_accno_id income_accno_id)) {
                $part->{$_} = $defaults{$_};
            }
            $part->{partsgroup_id} =
              $db->query("SELECT id FROM partsgroup ORDER BY 1 LIMIT 1")->list;
            $db->insert( 'parts', $part );
            $parts_id = $db->query("SELECT MAX(id) FROM parts")->list;
        }
        if ( !$create_inv ) {
            my $item = {
                parts_id     => $parts_id,
                description  => $item_hash->{name},
                qty          => $item_hash->{quantity},
                sellprice    => $item_hash->{price},
                unit         => 'each',
                ship         => 0,
                serialnumber => '',
                itemnotes    => '',
                ordernumber  => $data->{id},
                ponumber     => '',
            };
            push @{ $order->{items} }, $item;
        }
        else {
            my $item = {
                parts_id     => $parts_id,
                description  => $item_hash->{name},
                qty          => $item_hash->{quantity},
                sellprice    => $item_hash->{price},
                fxsellprice  => $item_hash->{price},
                unit         => 'each',
                serialnumber => '',
                itemnotes    => '',
                ordernumber  => $data->{id},
                ponumber     => '',
            };
            push @{ $order->{invoice} }, $item;

            $item = {
                warehouse_id  => 1,
                department_id => 1,
                parts_id      => $parts_id,
                qty           => $item_hash->{quantity},
                shipping_date => $data->{date_created_gmt},
                sellprice     => $item_hash->{price},
                serialnumber  => '',
                itemnotes     => '',
            };
            push @{ $order->{inventory} }, $item;
        }
    }

    my $customer = $db->query(
        "SELECT id from customer WHERE phone = ? OR email = ?",
        $order->{customer}->{phone},
        $order->{customer}->{email}
    )->hash;

    my $customer_id;

    if ($customer) {
        $customer_id = $customer->{id};
        $db->update( 'customer', $order->{customer}, { id => $customer_id } );
    }
    else {
        $db->insert( 'customer', $order->{customer} );
        $customer_id = $db->query("SELECT max(id) FROM customer")->list;
        $order->{address}->{trans_id} = $customer_id;
        $db->insert( 'address', $order->{address} );

        $order->{contact}->{trans_id} = $customer_id;
        $db->insert( 'contact', $order->{contact} );

        $order->{shipto}->{trans_id} = $customer_id;
        $db->insert( 'shipto', $order->{shipto} );
    }
    if ( !$create_inv ) {
        $order->{oe}->{customer_id} = $customer_id;
        $db->insert( 'oe', $order->{oe} );
        my $oe_id = $db->query("SELECT max(id) FROM oe")->list;

        foreach my $item ( @{ $order->{items} } ) {
            $item->{trans_id} = $oe_id;
            $db->insert( 'orderitems', $item );
        }
    }
    else {
        $order->{ar}->{customer_id} = $customer_id;
        $db->insert( 'ar', $order->{ar} );
        my $ar_id = $db->query("SELECT max(id) FROM ar")->list;
        foreach my $item ( @{ $order->{invoice} } ) {
            $item->{trans_id} = $ar_id;
            $db->insert( 'invoice', $item );
        }
    }

    return $c->render( status => 200, text => "Working" );

};

app->start;
