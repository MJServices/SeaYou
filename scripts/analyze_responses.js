const fs = require('fs');

try {
  let fileContent = fs.readFileSync('diagnostics_net_responses_output_utf8.json', 'utf8');
  if (fileContent.charCodeAt(0) === 0xFEFF) {
    fileContent = fileContent.substring(1);
  }
  const data = JSON.parse(fileContent);
  const responses = data[0]?.info?.responses || [];
  
  console.log(`Total responses fetched: ${responses.length}`);
  
  const urlCounts = {};
  const statusCounts = {};
  const timeouts = [];
  const errors = [];
  
  responses.forEach(r => {
    // We don't have direct url in response unless we fetch the request, but let's see if request info is inside 'r'
    // Let's inspect the keys of a single response record:
    // It has: id, content, created, headers, error_msg, timed_out, status_code, content_type
    // Wait, does pg_net responses keep the request URL? No, request URL might not be in the response table itself, 
    // but we can check if content or error messages contain URL details, or if there is another table.
    // Let's print the structure of the first response to verify what fields it has.
  });
  
  if (responses.length > 0) {
    console.log('Sample response structure keys:', Object.keys(responses[0]));
    console.log('Sample response:', JSON.stringify(responses[0], null, 2));
  }
} catch (e) {
  console.error('Error analyzing responses:', e);
}
