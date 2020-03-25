// When CloudFront is used in association with a S3 backend, and the origin protected using an OAI
// CloudFront does allow you to specify a default root object (index.html), it only works on the root of the website (such as http://www.example.com > http://www.example.com/index.html)
// PROBLEM: It does not work on any subdirectory (such as http://www.example.com/about/)
// If you were to attempt to request this URL through CloudFront, CloudFront would do a S3 GetObject API call against a key that does not exist
//
// If you want to keep the S3 backend safe, the solution is to trigger a Lambda@Edge with the following script
// CloudFront will inspect the request as it’s coming in from the client, then re-write the request so that CloudFront requests a default index object (index.html in this case) for any request URI that ends in ‘/’
// Source: https://aws.amazon.com/blogs/compute/implementing-default-directory-indexes-in-amazon-s3-backed-amazon-cloudfront-origins-using-lambdaedge/
// What is an OAI? http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html

'use strict';
exports.handler = (event, context, callback) => {
    
    // Extract the request from the CloudFront event that is sent to Lambda@Edge 
    var request = event.Records[0].cf.request;

    // Extract the URI from the request
    var olduri = request.uri;

    // Match any '/' that occurs at the end of a URI. Replace it with a default index
    var newuri = olduri.replace(/\/$/, '\/index.html');
    
    // Log the URI as received by CloudFront and the new URI to be used to fetch from origin
    console.log("Old URI: " + olduri);
    console.log("New URI: " + newuri);
    
    // Replace the received URI with the URI that includes the index page
    request.uri = newuri;
    
    // Return to CloudFront
    return callback(null, request);

};