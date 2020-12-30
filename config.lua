return {
    database = 'host=/var/run/postgresql/ user=checkup dbname=checkup sslmode=disable',
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
