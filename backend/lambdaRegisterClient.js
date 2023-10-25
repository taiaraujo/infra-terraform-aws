var AWS = require('aws-sdk');
var ddb = new AWS.DynamoDB();

exports.handler = async (event) => {
  try {
    const {id, name} = JSON.parse(event.body);
    var params = {
      TableName: 'Client',
      Item: {
        id: {S: id},
        name: {S: name}
      } 
    };
    var data;
    var message;

    try {
      data = await ddb.putItem(params).promise();
      message = "Sucessfull client register.";
    } catch (err) {
      message = err;
      console.log("ERROR: ", message)
    };

    var response = {
      'status_code': 200,
      'body': JSON.stringify({status_message: message})
    };

  } catch (error) {
    console.log("ERROR: ", err)
    return err;
  };

  return response
}