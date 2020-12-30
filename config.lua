return {
    database = 'host=/var/run/postgresql/ user=nightshift dbname=nightshift sslmode=disable',
    channels = {
        slack = os.getenv('SLACK_WEBHOOK')
    },
    monitors = {
        api_health = {
            type = 'http',
            interval_ms = 5000,
            threshold_ms = 1500,
            host = os.getenv('HOST'),
            alert = {'slack'}
        }
    }
}
