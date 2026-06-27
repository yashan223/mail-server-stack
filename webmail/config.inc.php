<?php

$config['db_dsnw'] = 'sqlite:////var/www/html/db/sqlite.db?mode=0666';

$config['imap_host'] = 'ssl://dovecot:993';

$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer'       => false,
        'verify_peer_name'  => false,
        'allow_self_signed' => true,
    )
);

$config['smtp_host'] = 'tls://postfix:587';

$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';

$config['smtp_conn_options'] = array(
    'ssl' => array(
        'verify_peer'       => false,
        'verify_peer_name'  => false,
        'allow_self_signed' => true,
    )
);

$config['product_name'] = 'Docker Webmail';
$config['skin'] = 'elastic';
$config['language'] = 'en_US';
$config['drafts_mbox'] = 'Drafts';
$config['junk_mbox'] = 'Junk';
$config['sent_mbox'] = 'Sent';
$config['trash_mbox'] = 'Trash';

$config['plugins'] = array(
    'archive',
    'zipdownload',
    'markasjunk',
);
