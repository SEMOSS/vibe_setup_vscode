You are going to create application for SEMOSS platform. You have access to python. So for operations such as converting to base 64 from and to, make use of python. 

Refering to local means the current desktop where you are running and local files. Referring to semoss means the remote version of the project. Along these lines, if you dont see it on semoss_config start by asking the user which semoss instance they want to use and record it as base_url. You can default base_url to : https://workshop.cfg.deloitte.com/ and the api_module_url to /cfg-ai-dev/Monolith and web_module_url to /cfg-ai-dev/SemossWeb. Make sure you replace these in mcp.json as well as you get started with your work. 


Your workflow always starts with 

a. Checking to see if the folder is connected to a project in the SEMOSS platform. You can do so by checking to see if there is a semoss_config file available. 
b. If there is no file there, offer to create a project and then persist the following details project id, the base url. If you are using the basic govconnect instance, you can default this to /cfg-ai-dev/Monolith. Once the information is available save this in semoss_config with the following details. 
- Project ID / APP ID
- Module 
- Created On 
Make this as a json so you can add additional details as needed. Once the project is created, persist this in the config directory of the remote project you just created. 

c. When saving files, always use the ai_server_sdk to perform this job. Here is the code snippet for you 
from ai_server import ModelEngine, ServerClient
access = "this is the first part of bearer token in mcp.json header authorization"
secret = "this is the second part of bearer token in mcp.json header authorization"
endpoint = 'https://workshop.cfg.deloitte.com/cfg-ai-dev/Monolith/api/'
# Create the server connection 
server_connection = ServerClient(base=endpoint, access_key=access, secret_key=secret)
# Create a new insight 
insight_id = server_connection.make_new_insight()
# Upload the local file
server_connection.upload_files(files=[path to local file 1, path to local file 2], project_id="<Project ID from semoss config>", insight_id=f"{insight_id}", path="/version/assets/<appropriate folder>")
First test to see if a file exists. If it does, prompt the user that you will delete it, once user confirms, delete the file. After this you have to publish the project otherwise it wont take effect. Then list the files to make sure it is not there and then upload with this new version. 
# Download remote file i.e. from semoss 
server_connection.download_file(file=["path_to_insight_file"], project_id="your_project_id", insight_id="your_insight_id",custom_filename="filename_for_download")
These methods are also available in scripts/semoss_asset_sync.py
 
 
d. If there are databases involved or need to be created, use the following app to tell the user to create the database and provide you with the dtabase id. Once provided use the get_schema (database_id) to get the schema. Please remember that you are getting a base64 encoded schema which needs to be decoded for use. Once you get the schema. Also write the schema into semoss_config. You can use the following python code to convert the file to base 64. 
import base64; from pathlib import Path; p=Path('portals/index.html'); Path('temp_portals_index_html.b64').write_text(base64.b64encode(p.read_bytes()).decode('utf-8'))
Create Base 64 of the files in the temp directory with the same structure so you are not confused. After it has been pushed, you can delete the file. 

e. Everytime you make modifications, give the option to the user to synchronize the file i.e. from local to remote and offer to publish the URL 
f. The projects all follow this URL pattern - <base_url><web_module_url>/packages/client/dist/#/app/<project ID/ App ID>/view. Please remember this and offer the user to see the website if they want to. 
g. If the user wants to creates a database, offer to create it through the database maker application which is located at URL : <base_url><web_module_url>/packages/client/dist/#/app/394404bf-02e5-44b2-bc7c-e93d9b698f58/view
h. If the user wants to access an existing database with a specific id offer to take them to the URL : <base_url><web_module_url>/packages/client/dist/#/engine/database/<database id>
h. If the user is trying to give you a task and it is a complex task, show them a list of things like a task list you will do and ask them to confirm before proceeding. 
i. Do not put write file, put file etc calls into the context ever. It is a waste of context space. 


Please only use the specified MCPs and nothing more. Please make sure you are not trying alternative paths. You should NEVER EVER install any new library therefore, no need to create a python virtual environment. You can run python commands for simple things, but dont do anything dangerous. 

You can run Python, but dont use Pylance. I dont need to run un-necessary mcps. 

The UI is always built as single page html unless otherwise specified. Please make sure you are making this in the appropriate directories and directory structure.

Before you start up the MCP note that the MCPs have placeholder for accessKey and SecretKey, you need to ask the user for it and put it in appropriate places to get started. If the access key secret key is already there just confirm it is there. 

Remember everything you are building is on SEMOSS so start by getting familiar with the instructions. 

As a starting point list the tools from the MCPs so the users are aware of them. 

ALWAYS be concise, dont create monstrous code which is impossible to review.