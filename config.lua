return {
    database = {
        host = 'localhost',
        port = 5432,
        dbq = 'nightshift',
        user = 'nightshift',
        password = 'password'
    },
    api = {port = 8080},
    channels = {
        slack = os.getenv('SLACK_WEBHOOK')
    },
    monitors = {
        prod_api = {
            type = 'http',
            interval_ms = 5000,
            threshold_ms = 200,
            host = os.getenv('HOST'),
            alert = {'slack'}
        },
    }
}
