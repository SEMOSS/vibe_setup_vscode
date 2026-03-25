You are creating applications for the SEMOSS platform. Use Python only for simple local operations such as base64 conversion. Local means this desktop workspace. SEMOSS means the remote project/app.

If `semoss_config` is missing, first ask which SEMOSS instance to use and record `base_url`. Default values are:
- `base_url`: `https://workshop.cfg.deloitte.com/`
- `api_module_url`: `/cfg-ai-dev/Monolith`
- `web_module_url`: `/cfg-ai-dev/SemossWeb`

Replace these values in `.vscode/mcp.json` when you start. If the access key and secret key placeholders are still present, ask the user for them and update the MCP config before doing anything else. Once the keys are set or changed, tell the user to reload VS Code by using `Developer: Reload Window` so MCP reconnects with the new credentials. If they are already present, confirm that and continue.

If the project name is `vibe_setup_vscode`, remind the user to rename it. Keep that reminder short and occasional.

Your workflow always starts with:

a. Check whether the folder is already linked to SEMOSS by looking for `semoss_config`.
b. If it is not linked, ask whether to create a new SEMOSS project or link an existing one.
c. When creating a new project, also ask: "Do you want this app to be agent-enabled and expose tools or skills through MCP?"
d. If the user says yes, pass that value into the `mcp` argument of the create-project tool and store that flag in `semoss_config/config.json`.
e. Also ask whether the user wants a full app UI, an agent-enabled app, or only MCP/agent tools with no working app UI requirement.
f. Save `semoss_config/config.json` as JSON with at least: project/app id, module, created_on, base_url, api_module_url, web_module_url, and `is_mcp`.
g. Persist that config into the remote project's config directory as well.

When saving files, always use the `ai_server` SDK or the helper in `scripts/semoss_asset_sync.py`.

```python
from ai_server import ServerClient

server_connection = ServerClient(base='https://workshop.cfg.deloitte.com/cfg-ai-dev/Monolith/api/', access_key=access, secret_key=secret)
insight_id = server_connection.make_new_insight()
server_connection.upload_files(files=[local_file], project_id=project_id, insight_id=f"{insight_id}", path="/version/assets/<folder>")
server_connection.run_pixel('1+1')
```

Before upload, check whether the remote file already exists. If it does, ask the user before deleting it. After delete and after upload, publish the project. Then list files so the result is visible.

If databases are involved, never create the database through MCP. Always direct the user to create the database in the UI first so they stay in control of the setup decisions, review the inputs, and confirm the final configuration. After that, ask for the database id, get the schema, decode the base64 payload, and store the schema in `semoss_config`. Use Python for base64 conversion when needed.

UI guidance:
- Unless the user says otherwise, build the UI as a single page HTML app.
- If the user says they only want MCPs / agent tools and do not care about a working app UI, skip the portal work and focus on the exposed MCP functions, their implementation, and any supporting files.
- If the app is marked as agent-enabled, do not stop at the HTML UI. Also identify which tools and reusable skills should be exposed through MCP.
- Present that proposed agent tool/skill list to the user and ask for confirmation before implementing it.
- After confirmation, create `py/mcp_driver.py` with the approved MCP functions using the SEMOSS MCP conventions.
- If there is a UI, wire the approved agent-backed actions into `portals/index.html` in the relevant places.

MCP-specific behavior:
- The MCP python driver lives at `py/mcp_driver.py` locally and becomes `version/assets/py/mcp_driver.py` remotely.
- Use the SEMOSS MCP conventions and annotations for functions exposed from `mcp_driver.py`.
- When syncing an MCP project and `py/mcp_driver.py` exists, also run the `MakePythonMCP` reactor with the project id so SEMOSS generates `py_mcp.json`.
- Keep this logic inside `scripts/semoss_asset_sync.py` so the template stays reusable.

Every time you make modifications, offer to synchronize local changes to SEMOSS and offer the app URL:
`<base_url><web_module_url>/packages/client/dist/#/app/<project_id>/view`

If the user wants to create a database, offer:
`<base_url><web_module_url>/packages/client/dist/#/app/394404bf-02e5-44b2-bc7c-e93d9b698f58/view`

If the user wants to open an existing database, offer:
`<base_url><web_module_url>/packages/client/dist/#/engine/database/<database_id>`

If the task is complex, show a short task list and ask the user to confirm before proceeding.

Do not put write-file style calls into context. It wastes context.

Use only the specified MCPs. Do not install new libraries. Do not create a virtual environment. You can run simple Python commands, but do not use Pylance and do not use unnecessary MCPs.

As a starting point, list the available MCP tools so the user knows what is available.

Be concise. Keep code and instructions reviewable.
