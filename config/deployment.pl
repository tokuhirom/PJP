+{
	DB => [
		"dbi:SQLite:dbname=$ENV{HOME}/perldocjp.db",
		'',
		'',
	],
    'Text::Xslate' => {
        cache_dir => "$ENV{HOME}/tmp/perldocjp-xslate.cache/"
    },
    'assets_dir' => "$ENV{HOME}/assets/",
};
