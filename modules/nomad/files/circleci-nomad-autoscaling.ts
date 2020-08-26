// const AWS = require('aws-sdk');
import * as AWS from 'aws-sdk';
import * as async from 'async';

const as = new AWS.AutoScaling();
const ssm = new AWS.SSM();

//const documentName = 'CircleCiDrainNodes' ; //name of the document to be executed on nodes

const { 
    s3bucket, 
    documentName,
    region
} = process.env;

export const handler = async (notification, _context) => {
    console.log("INFO: request Recieved.\nDetails:\n", JSON.stringify(notification));
    const message = JSON.parse(notification.Records[0].Sns.Message);
    console.log("DEBUG: SNS message contents. \nMessage:\n", message);
    
    const instanceId = message.EC2InstanceId;
    console.log(instanceId);

    let lifecycleParams = {
        "AutoScalingGroupName": message.AutoScalingGroupName,
        "LifecycleHookName": message.LifecycleHookName,
        "LifecycleActionToken": message.LifecycleActionToken,
        "LifecycleActionResult": "CONTINUE"
    };
    
    executeCommand(instanceId, lifecycleParams, _context);

};

const wait = () => {
    return new Promise((resolve, reject) => {
        setTimeout(() => resolve(""), 2000)
    });
}

const executeCommand = (nodename, lifecycleParams, context) =>{
    const ssmparams = {
        DocumentName: documentName,
        Comment: 'Draining Nomad Node', //any comment
        OutputS3BucketName: s3bucket, //save the logs in this bucket
        OutputS3KeyPrefix: 'ssm-nomad-logs', //bucket prefix
        OutputS3Region: region, //region of bucket
        InstanceIds: [nodename],
        Parameters: {
            'nodename': [
                nodename
            ]
        }
    };
    ssm.sendCommand(ssmparams, function(err, data) {
        if (err) console.log(err, err.stack);
        else {
            console.log(data);
            let commandid = data.Command.CommandId;
            waitCommandSuccess(commandid, function waitCommandReadyCallback(err) {
                if (err) {
                    console.log("ERROR: Failure waiting for Command to be Success");
                    console.log(err);
                    recordLifecycleActionHeartbeat(lifecycleParams, function lifecycleActionResponseHandler(err) {
                        if (err) {
                            context.fail();
                        } else {
                            //if we successfully notified AutoScaling of the instance status, tell lambda we succeeded
                            //even if the operation on the instance failed
                            context.succeed();
                        }
                    });
                } else {
                    console.log("Command Status is Success");
                    completeAsLifecycleAction(lifecycleParams, function lifecycleActionResponseHandler(err) {
                            if (err) {
                                context.fail();
                            } else {
                                //if we successfully notified AutoScaling of the instance status, tell lambda we succeeded
                                //even if the operation on the instance failed
                                context.succeed();
                            }
                    });
                }
            });
        }
    });
}

const waitCommandSuccess = (commandid, waitCommandReadyCallback) => {
    var commandStatus = undefined;
    async.until(
        function isSuccess(err) {
            return commandStatus === "Success";
        },
        function getCommandStatus(getCommandStatusCallback) {
            ssm.listCommands({
                CommandId: commandid
            }, function(err, data) {
                if (err) console.log(err, err.stack); 
                else {
                    console.log(data.Commands[0].Status);
                    commandStatus = data.Commands[0].Status;
                    wait()
                    getCommandStatusCallback(err)
                }
            });
        },
        function waitCommandReadyCallbackClosure(err) {
            if (err) {
                console.log("ERROR: error waiting for Command to be success:\n", err);
            }
            waitCommandReadyCallback(err);
        }
    );
}

const recordLifecycleActionHeartbeat = (lifecycleParams, callback) => {
    //returns true on success or false on failure
    //notifies AutoScaling that it should either continue or abandon the instance
    as.recordLifecycleActionHeartbeat(lifecycleParams, function(err, data) {
        if (err) {
            console.log("ERROR: AS lifecycle completion failed.\nDetails:\n", err);
            console.log("DEBUG: CompleteLifecycleAction\nParams:\n", lifecycleParams);
            callback(err);
        } else {
            console.log("INFO: CompleteLifecycleAction Successful.\nReported:\n", data);
            callback(null);
        }
    });
}

const completeAsLifecycleAction = (lifecycleParams, callback) => {
    //returns true on success or false on failure
    //notifies AutoScaling that it should either continue or abandon the instance
    as.completeLifecycleAction(lifecycleParams, function(err, data) {
        if (err) {
            console.log("ERROR: AS lifecycle completion failed.\nDetails:\n", err);
            console.log("DEBUG: CompleteLifecycleAction\nParams:\n", lifecycleParams);
            callback(err);
        } else {
            console.log("INFO: CompleteLifecycleAction Successful.\nReported:\n", data);
            callback(null);
        }
    });
}
