<?php
define( 'DB_NAME', getenv('WP_DATABASE_NAME') );
define( 'DB_USER', getenv('WP_DATABASE_USER') );
define( 'DB_PASSWORD', getenv('WP_DATABASE_PASSWORD') );
define( 'DB_HOST', getenv('WP_DATABASE_HOST').':'.getenv('WP_DATABASE_PORT') );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         '{UeSWs;1M+N]FG5kOT+AfW;CnlC0vdU?$suzeo|r1WePDjM|]2HX!iHqKCuz6(sm');
define('SECURE_AUTH_KEY',  ' !FMV7qw%Wc%)+WnFtG+H6bb_d_!X3m_v5<+kV@#=i/0-&^b s8b ;RtzX;0r9u6');
define('LOGGED_IN_KEY',    '^H;yd$-=e5,:M1 =^8:hh{7I[,1++=*]e?^PIVZ`*aOEed-oVcTS1ZEeD@UR*0| ');
define('NONCE_KEY',        'Y>sweI8kZW@+TV^s,2<h-,&_F?Tsr.|m0]Kv~Ak|%@5sZM#43k-B>E~0G0Q0KZ$K');
define('AUTH_SALT',        '6vMuDnB6jbAYHdedX<$EWo>W2d#(c%WVh6)faG,TIx;`]?Z%v4|2R+?$lsLP[|uz');
define('SECURE_AUTH_SALT', 'B~JRZe!g8=~|s%j%,CV1[$el)TT:>Gz>nMR%,P|I&y??:=|^yHh5fi]}?+mSG>q+');
define('LOGGED_IN_SALT',   '_|F:.0cqr7[FwU2-!N+1W-gmfGBJA*.QD=uP!hQ=h}q]Q;}a7Ls1U}N&N[lI~+-8');
define('NONCE_SALT',       'w;MGCxU0P/7+6n.Wg~;/eubk&O|%fdL-fMcBweEd4sZ7~QKtd/kQ7H|P3!Xz`u|+');

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the Codex.
 *
 * @link https://codex.wordpress.org/Debugging_in_WordPress
 */
define( 'WP_DEBUG', false );
define( 'WP_CONTENT_DIR', __DIR__ . '/wp-content' );
define( 'WP_CONTENT_URL', '/wp-content' );

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}

/** Sets up WordPress vars and included files. */
require_once( ABSPATH . 'wp-settings.php' );
