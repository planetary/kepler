config = require '../config'

async = require 'async'
aws = require 'aws-sdk'
base64 = require 'base64-stream'
child = require 'child_process'
path = require 'path'
Promise = require 'bluebird'


s3 = new aws.S3(
    'apiVersion': '2006-03-01'
    'region': config.aws.region
)


queue = async.queue((request, next) ->
    async.auto({
        'phantom': (next) ->
            # spawn child process and feed it input
            phantom = child.spawn(
                config.screenshots.phantom
                [path.join( __dirname, 'capture.phantom.js' )]
                {'stdio': ['pipe', 'pipe', 'ignore']}
            )
            phantom.stdin.end(JSON.stringify(request))

            next(null, phantom)
        'wait': ['spawn', (next, ctx) ->
            # wait for the process to end, helping it if necessary
            # http://bit.ly/1B4ToFb
            timer = setTimeout(
                -> ctx.phantom.kill(9)
                config.screenshots.timeout
            )

            ctx.phantom.on 'close', (code) ->
                timer.clearTimeout()
                if code
                    next(new Error("Child process crashed with #{code}"))
                next()
        ]
        'upload': ['spawn', (next, ctx) ->
            s3.upload({
                'ACL': 'public-read'
                'Bucket': config.aws.bucket
                'Key': request.key
                'Body': phantom.stdout.pipe(base64.decode())
                'ContentType': "image/#{request.format}"
                'StorageClass': if config.aws.reliable then 'STANDARD'\
                                else 'REDUCED_REDUNDANCY'
            }, next)
        ]
    }, next)
, config.screenshots.concurrency)


module.exports = queue.push.bind(queue)
