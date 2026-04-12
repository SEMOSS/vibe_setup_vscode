from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

try:
    import requests
except ImportError:  # pragma: no cover - fallback when requests is unavailable
    requests = None

from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


WORKSPACE_ROOT = Path(__file__).resolve().parents[1]
MCP_CONFIG_PATH = WORKSPACE_ROOT / ".vscode" / "mcp.json"
SEMOSS_CONFIG_PATH = WORKSPACE_ROOT / "semoss_config" / "config.json"
DEFAULT_HOST = "https://workshop.cfg.deloitte.com"
DEFAULT_API_MODULE_URL = "/cfg-ai-dev/Monolith"
DEFAULT_WEB_MODULE_URL = "/cfg-ai-dev/SemossWeb"
SERVER_NAME = "Semoss_project_manager"
BACKUP_ROOT = WORKSPACE_ROOT / "temp" / "semoss_backups"
MCP_DRIVER_PATH = WORKSPACE_ROOT / "py" / "mcp_driver.py"
DEFAULT_MCP_SERVER_PATHS = {
    "Semoss_Platform_Instructions": "/api/ext/mcp/67aa0dcf-04f5-460f-9075-bad8eeedad7e/comms",
    "Semoss_project_manager": "/api/ext/mcp/03e8cbeb-2f76-4213-9766-57448a3837a4/comms",
    "Semoss_database_helper": "/api/ext/mcp/394404bf-02e5-44b2-bc7c-e93d9b698f58/comms",
}


def normalize_base_url(base_url: str) -> str:
    cleaned = base_url.strip()
    if not cleaned:
        return DEFAULT_HOST
    return cleaned.rstrip("/")


def normalize_module_url(module_url: str, default_value: str) -> str:
    cleaned = module_url.strip()
    if not cleaned:
        cleaned = default_value
    return "/" + cleaned.strip("/")


def build_semoss_module_base(base_url: str, api_module_url: str) -> str:
    return f"{normalize_base_url(base_url)}{normalize_module_url(api_module_url, DEFAULT_API_MODULE_URL)}"


def build_mcp_bearer_value(access_key: str, secret_key: str) -> str:
    return f"Authorization:Bearer{access_key.strip()}:{secret_key.strip()}"


def build_default_mcp_config() -> dict[str, object]:
    servers: dict[str, object] = {}
    for server_name, server_path in DEFAULT_MCP_SERVER_PATHS.items():
        servers[server_name] = {
            "type": "stdio",
            "command": "npx",
            "tools": ["*"],
            "args": [
                "-y",
                "mcp-remote",
                f"<base_url><api_module_url>{server_path}",
                "--header",
                "Authorization:Bearer<accessKey:secretKey>",
            ],
        }
    return {"servers": servers, "inputs": []}


def load_json_config(config_path: Path, default_value: dict[str, object]) -> dict[str, object]:
    if not config_path.exists():
        return json.loads(json.dumps(default_value))

    raw_text = config_path.read_text(encoding="utf-8").strip()
    if not raw_text:
        return json.loads(json.dumps(default_value))

    data = json.loads(raw_text)
    if not isinstance(data, dict):
        raise RuntimeError(f"{config_path} must contain a JSON object.")
    return data


def write_json_config(config_path: Path, payload: dict[str, object]) -> None:
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def update_mcp_server_args(args: list[object], module_base: str, bearer_value: str, fallback_path: str) -> list[object]:
    updated_args = list(args)
    remote_url_index = None
    header_index = None

    for index, arg in enumerate(updated_args):
        if not isinstance(arg, str):
            continue
        if arg == "mcp-remote" and index + 1 < len(updated_args):
            remote_url_index = index + 1
        elif arg == "--header" and index + 1 < len(updated_args):
            header_index = index + 1

    if remote_url_index is None:
        updated_args.extend(["mcp-remote", f"{module_base}{fallback_path}"])
    else:
        current_value = str(updated_args[remote_url_index])
        marker = "/api/ext/mcp/"
        if marker in current_value:
            _, _, suffix = current_value.partition(marker)
            updated_args[remote_url_index] = f"{module_base}{marker}{suffix}"
        else:
            updated_args[remote_url_index] = f"{module_base}{fallback_path}"

    if header_index is None:
        updated_args.extend(["--header", bearer_value])
    else:
        updated_args[header_index] = bearer_value

    return updated_args


def update_mcp_config_file(
    mcp_config_path: Path,
    base_url: str,
    api_module_url: str,
    access_key: str,
    secret_key: str,
) -> dict[str, object]:
    config = load_json_config(mcp_config_path, build_default_mcp_config())
    servers = config.setdefault("servers", {})
    if not isinstance(servers, dict):
        raise RuntimeError(".vscode/mcp.json must contain a 'servers' object.")

    module_base = build_semoss_module_base(base_url, api_module_url)
    bearer_value = build_mcp_bearer_value(access_key, secret_key)

    for server_name, fallback_path in DEFAULT_MCP_SERVER_PATHS.items():
        server_config = servers.get(server_name)
        if not isinstance(server_config, dict):
            server_config = {
                "type": "stdio",
                "command": "npx",
                "tools": ["*"],
                "args": [],
            }
            servers[server_name] = server_config

        existing_args = server_config.get("args", [])
        if not isinstance(existing_args, list):
            existing_args = []

        server_config["type"] = server_config.get("type", "stdio")
        server_config["command"] = server_config.get("command", "npx")
        server_config["tools"] = server_config.get("tools", ["*"])
        server_config["args"] = update_mcp_server_args(existing_args, module_base, bearer_value, fallback_path)

    write_json_config(mcp_config_path, config)
    return config


def update_semoss_config_file(
    config_path: Path,
    project_id: str | None,
    base_url: str,
    api_module_url: str,
    web_module_url: str,
    is_mcp: bool | None,
    module: str | None,
) -> dict[str, object]:
    config = load_semoss_config(config_path)
    resolved_project_id = project_id or str(
        config.get("project_id")
        or config.get("app_id")
        or config.get("projectId")
        or config.get("appId")
        or ""
    )
    resolved_module = module or str(config.get("module") or "app")
    resolved_is_mcp = is_mcp if is_mcp is not None else parse_bool(config.get("is_mcp"))
    created_on = str(config.get("created_on") or datetime.now().isoformat(timespec="seconds"))

    updated_config = dict(config)
    updated_config.update(
        {
            "project_id": resolved_project_id,
            "app_id": resolved_project_id,
            "module": resolved_module,
            "created_on": created_on,
            "base_url": normalize_base_url(base_url) + "/",
            "api_module_url": normalize_module_url(api_module_url, DEFAULT_API_MODULE_URL),
            "web_module_url": normalize_module_url(web_module_url, DEFAULT_WEB_MODULE_URL),
            "is_mcp": resolved_is_mcp,
        }
    )

    write_json_config(config_path, updated_config)
    return updated_config


def configure_local_semoss_files(
    access_key: str,
    secret_key: str,
    base_url: str = DEFAULT_HOST,
    api_module_url: str = DEFAULT_API_MODULE_URL,
    web_module_url: str = DEFAULT_WEB_MODULE_URL,
    project_id: str | None = None,
    is_mcp: bool | None = None,
    module: str | None = None,
) -> dict[str, object]:
    if not access_key.strip() or not secret_key.strip():
        raise SystemExit("Both access_key and secret_key are required.")

    updated_mcp = update_mcp_config_file(
        mcp_config_path=MCP_CONFIG_PATH,
        base_url=base_url,
        api_module_url=api_module_url,
        access_key=access_key,
        secret_key=secret_key,
    )
    updated_semoss = update_semoss_config_file(
        config_path=SEMOSS_CONFIG_PATH,
        project_id=project_id,
        base_url=base_url,
        api_module_url=api_module_url,
        web_module_url=web_module_url,
        is_mcp=is_mcp,
        module=module,
    )

    return {
        "mcp_config_path": str(MCP_CONFIG_PATH),
        "semoss_config_path": str(SEMOSS_CONFIG_PATH),
        "module_base": build_semoss_module_base(base_url, api_module_url),
        "mcp_servers": sorted(updated_mcp.get("servers", {}).keys()),
        "project_id": updated_semoss.get("project_id", ""),
        "is_mcp": updated_semoss.get("is_mcp", False),
        "base_url": updated_semoss.get("base_url", ""),
        "api_module_url": updated_semoss.get("api_module_url", ""),
        "web_module_url": updated_semoss.get("web_module_url", ""),
    }


def load_semoss_config(config_path: Path) -> dict[str, object]:
    if not config_path.exists():
        return {}

    raw_text = config_path.read_text(encoding="utf-8").strip()
    if not raw_text:
        return {}

    data = json.loads(raw_text)
    if not isinstance(data, dict):
        raise RuntimeError("semoss_config/config.json must contain a JSON object.")
    return data


def load_bearer_parts(mcp_config_path: Path) -> tuple[str, str]:
    config = json.loads(mcp_config_path.read_text(encoding="utf-8"))
    server = config["servers"][SERVER_NAME]
    args = server.get("args", [])

    header_value = None
    for index, arg in enumerate(args):
        if arg == "--header" and index + 1 < len(args):
            header_value = args[index + 1]

    if not header_value:
        raise RuntimeError(f"No Authorization header found for server '{SERVER_NAME}'.")

    prefix = "Authorization:Bearer"
    if not header_value.startswith(prefix):
        raise RuntimeError("Unexpected Authorization header format in mcp.json.")

    bearer_value = header_value[len(prefix):]
    if "<accessKey:secretKey>" in bearer_value:
        raise RuntimeError("Replace the placeholder accessKey and secretKey values in .vscode/mcp.json.")

    access_token, secret = bearer_value.split(":", 1)
    return access_token, secret


def build_api_endpoint(semoss_config: dict[str, object]) -> str:
    semoss_base_url = str(semoss_config.get("base_url", "")).strip()
    api_module_url = str(semoss_config.get("api_module_url", "")).strip()

    if semoss_base_url:
        if api_module_url:
            return f"{semoss_base_url.rstrip('/')}/{api_module_url.strip('/')}/api/"
        return f"{semoss_base_url.rstrip('/')}/api/"

    return f"{build_semoss_module_base(DEFAULT_HOST, DEFAULT_API_MODULE_URL)}/api/"


def build_server_connection(endpoint: str, access_token: str, secret: str):
    try:
        from ai_server import ServerClient
    except ImportError as exc:
        raise RuntimeError(
            "Unable to import ServerClient from ai_server. "
            "Make sure the SEMOSS Python SDK is installed in this environment."
        ) from exc

    return ServerClient(base=endpoint, access_key=access_token, secret_key=secret)


def parse_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def get_project_id(semoss_config: dict[str, object]) -> str:
    candidate_values = [
        semoss_config.get("project_id"),
        semoss_config.get("app_id"),
        semoss_config.get("projectId"),
        semoss_config.get("appId"),
    ]

    for value in candidate_values:
        if value:
            return str(value)
    return ""


def is_mcp_project(semoss_config: dict[str, object]) -> bool:
    candidate_values = [semoss_config.get("is_mcp"), semoss_config.get("mcp")]
    return any(parse_bool(value) for value in candidate_values)


def should_generate_python_mcp(semoss_config: dict[str, object]) -> bool:
    return is_mcp_project(semoss_config) and MCP_DRIVER_PATH.exists()


def normalize_remote_asset_path(remote_path: str) -> str:
    cleaned = remote_path.strip().replace("\\", "/").strip("/")
    if not cleaned:
        raise ValueError("Remote asset path must not be empty.")
    if cleaned == "version/assets":
        return cleaned
    if cleaned.startswith("version/assets/"):
        return cleaned.rstrip("/")
    return f"version/assets/{cleaned}".rstrip("/")


def infer_remote_directory(local_file: Path) -> str:
    relative_path = local_file.relative_to(WORKSPACE_ROOT)
    parent = relative_path.parent.as_posix()
    if not parent or parent == ".":
        return "version/assets"
    return f"version/assets/{parent}"


def infer_remote_file_path(local_file: Path) -> str:
    relative_path = local_file.relative_to(WORKSPACE_ROOT).as_posix()
    return f"version/assets/{relative_path}"


def default_local_path_for_remote(remote_path: str) -> Path:
    normalized = normalize_remote_asset_path(remote_path)
    relative_path = normalized.removeprefix("version/assets/")
    if not relative_path or relative_path == "version/assets":
        return WORKSPACE_ROOT
    return WORKSPACE_ROOT / Path(relative_path)


def pixel_output(response: dict) -> object:
    pixel_return = response.get("pixelReturn", [])
    if not pixel_return:
        raise RuntimeError("SEMOSS pixel response did not contain any return payload.")
    return pixel_return[0].get("output")


def run_project_pixel(server_connection, pixel: str, insight_id: str | None = None) -> object:
    response = server_connection.run_pixel(pixel, insight_id=insight_id, full_response=True)
    return pixel_output(response)


def browse_remote_directory(server_connection, project_id: str, directory_path: str) -> list[dict[str, object]]:
    pixel = f'BrowseAsset(filePath=["{directory_path}"], space=["{project_id}"]);'
    output = run_project_pixel(server_connection, pixel)
    if isinstance(output, list):
        return [item for item in output if isinstance(item, dict)]
    if isinstance(output, dict):
        return [output]
    return []


def get_remote_asset_entry(server_connection, project_id: str, remote_asset_path: str) -> dict[str, object] | None:
    normalized_path = normalize_remote_asset_path(remote_asset_path)
    if normalized_path == "version/assets":
        return {
            "path": normalized_path,
            "name": "assets",
            "type": "directory",
        }

    parent_path, _, asset_name = normalized_path.rpartition("/")
    for item in browse_remote_directory(server_connection, project_id, parent_path):
        if item.get("name") == asset_name:
            return item
    return None


def remote_asset_exists(server_connection, project_id: str, remote_file_path: str) -> bool:
    remote_directory, _, remote_name = remote_file_path.rpartition("/")
    for item in browse_remote_directory(server_connection, project_id, remote_directory):
        if item.get("name") == remote_name:
            return True
    return False


def delete_remote_asset(server_connection, project_id: str, remote_file_path: str) -> object:
    pixel = f'DeleteAsset(filePath=["{remote_file_path}"], space=["{project_id}"]);'
    return run_project_pixel(server_connection, pixel)


def publish_project(server_connection, project_id: str) -> object:
    pixel = f"PublishProject(project='{project_id}', release=true);"
    return run_project_pixel(server_connection, pixel)


def make_python_mcp(server_connection, project_id: str) -> object:
    pixel = f"MakePythonMCP({json.dumps(project_id)});"
    return run_project_pixel(server_connection, pixel)


def confirm_remote_delete(remote_file_path: str) -> bool:
    response = input(f"Remote asset {remote_file_path} exists. Delete it before upload? [y/N]: ")
    return response.strip().lower() in {"y", "yes"}


def confirm_local_overwrite(local_path: Path) -> bool:
    response = input(f"Local path {local_path} exists. Overwrite it? [y/N]: ")
    return response.strip().lower() in {"y", "yes"}


def build_backup_path(local_file: Path) -> Path:
    relative_path = local_file.relative_to(WORKSPACE_ROOT)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_directory = BACKUP_ROOT / relative_path.parent
    backup_directory.mkdir(parents=True, exist_ok=True)
    backup_name = f"{relative_path.stem}-{timestamp}{relative_path.suffix}"
    return backup_directory / backup_name


def build_cookie_header(cookies) -> str:
    if cookies is None:
        return ""

    if hasattr(cookies, "get_dict"):
        values = cookies.get_dict()
    elif isinstance(cookies, dict):
        values = cookies
    else:
        try:
            values = {cookie.name: cookie.value for cookie in cookies}
        except Exception:  # pragma: no cover - fallback for unexpected cookie jars
            return ""

    return "; ".join(f"{key}={value}" for key, value in values.items() if value is not None)


def stream_download(download_url: str, cookies, destination_path: Path) -> None:
    if requests is not None:
        response = requests.get(download_url, cookies=cookies, stream=True, timeout=120)
        response.raise_for_status()
        with destination_path.open("wb") as handle:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    handle.write(chunk)
        return

    headers = {}
    cookie_header = build_cookie_header(cookies)
    if cookie_header:
        headers["Cookie"] = cookie_header

    request = Request(download_url, headers=headers)
    try:
        with urlopen(request, timeout=120) as response, destination_path.open("wb") as handle:
            while True:
                chunk = response.read(8192)
                if not chunk:
                    break
                handle.write(chunk)
    except (HTTPError, URLError) as exc:  # pragma: no cover - network failures bubble up
        raise RuntimeError(f"Failed to download asset from {download_url}") from exc


def download_remote_asset(
    server_connection,
    project_id: str,
    remote_file_path: str,
    insight_id: str,
    destination_path: Path,
) -> Path:
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        downloaded_file = server_connection.download_file(
            file=remote_file_path,
            project_id=project_id,
            insight_id=insight_id,
            custom_filename=str(destination_path),
        )
        return Path(downloaded_file).resolve()
    except Exception as exc:
        if "{project_id}" not in str(exc):
            raise

    download_key = run_project_pixel(
        server_connection,
        f"DownloadAsset(filePath=['{remote_file_path}'], space=['{project_id}']);",
        insight_id=insight_id,
    )
    download_url = (
        f"{server_connection.main_url}/engine/downloadFile"
        f"?insightId={insight_id}&fileKey={download_key}"
    )
    stream_download(download_url, server_connection.cookies, destination_path)

    return destination_path.resolve()


def print_directory_state(label: str, files: list[dict[str, object]]) -> None:
    print(label)
    print(json.dumps(files, indent=2, default=str))


def sync_remote_folder_to_local(
    server_connection,
    project_id: str,
    remote_folder_path: str,
    local_folder_path: Path,
    overwrite: bool = False,
) -> dict[str, list[str]]:
    normalized_remote_path = normalize_remote_asset_path(remote_folder_path)
    remote_entry = get_remote_asset_entry(server_connection, project_id, normalized_remote_path)
    if remote_entry is None:
        raise FileNotFoundError(f"Remote asset not found: {normalized_remote_path}")
    if remote_entry.get("type") != "directory":
        raise NotADirectoryError(f"Remote asset is not a directory: {normalized_remote_path}")

    local_folder_path.mkdir(parents=True, exist_ok=True)
    insight_id = str(server_connection.make_new_insight())
    downloaded: list[str] = []
    skipped: list[str] = []

    for item in browse_remote_directory(server_connection, project_id, normalized_remote_path):
        remote_item_path = str(item.get("path", ""))
        item_name = str(item.get("name", ""))
        item_type = str(item.get("type", ""))
        if not remote_item_path or not item_name:
            continue

        local_item_path = local_folder_path / item_name
        if item_type == "directory":
            nested = sync_remote_folder_to_local(
                server_connection=server_connection,
                project_id=project_id,
                remote_folder_path=remote_item_path,
                local_folder_path=local_item_path,
                overwrite=overwrite,
            )
            downloaded.extend(nested["downloaded"])
            skipped.extend(nested["skipped"])
            continue

        if local_item_path.exists() and not overwrite and not confirm_local_overwrite(local_item_path):
            skipped.append(str(local_item_path))
            continue

        saved_path = download_remote_asset(
            server_connection=server_connection,
            project_id=project_id,
            remote_file_path=remote_item_path,
            insight_id=insight_id,
            destination_path=local_item_path,
        )
        downloaded.append(str(saved_path))

    return {
        "downloaded": downloaded,
        "skipped": skipped,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Upload local assets to SEMOSS or sync remote assets to local.")
    subparsers = parser.add_subparsers(dest="command")

    configure_parser = subparsers.add_parser(
        "configure-local",
        help="Update local SEMOSS config files (.vscode/mcp.json and semoss_config/config.json).",
    )
    configure_parser.add_argument("--access-key", required=True, help="SEMOSS access key for the MCP bearer header.")
    configure_parser.add_argument("--secret-key", required=True, help="SEMOSS secret key for the MCP bearer header.")
    configure_parser.add_argument("--base-url", default=DEFAULT_HOST, help="SEMOSS host URL.")
    configure_parser.add_argument("--api-module-url", default=DEFAULT_API_MODULE_URL, help="SEMOSS API module path.")
    configure_parser.add_argument("--web-module-url", default=DEFAULT_WEB_MODULE_URL, help="SEMOSS web module path.")
    configure_parser.add_argument("--project-id", help="SEMOSS project/app id.")
    configure_parser.add_argument("--module", help="Project module value stored in semoss_config/config.json.")
    configure_parser.set_defaults(is_mcp=None)
    configure_parser.add_argument("--is-mcp", dest="is_mcp", action="store_true", help="Mark the project as MCP-enabled.")
    configure_parser.add_argument("--is-not-mcp", dest="is_mcp", action="store_false", help="Mark the project as not MCP-enabled.")

    upload_parser = subparsers.add_parser("upload", help="Upload a local file into the linked SEMOSS project.")
    upload_parser.add_argument("file", help="Path to the local file to upload.")

    sync_parser = subparsers.add_parser("sync-from-remote", help="Download a remote SEMOSS asset folder into the local workspace.")
    sync_parser.add_argument("remote_folder", help="Remote folder path, relative to version/assets or as a full version/assets path.")
    sync_parser.add_argument(
        "--local-dir",
        dest="local_dir",
        help="Local destination directory. Defaults to the workspace-relative folder matching the remote path.",
    )
    sync_parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing local files without prompting.",
    )
    return parser


def parse_args() -> argparse.Namespace:
    parser = build_parser()
    raw_args = sys.argv[1:]
    if raw_args and raw_args[0] not in {"configure-local", "upload", "sync-from-remote", "-h", "--help"}:
        raw_args = ["upload", *raw_args]
    if not raw_args:
        parser.print_help()
        raise SystemExit(2)
    return parser.parse_args(raw_args)


def build_semoss_context() -> tuple[dict[str, object], str, object]:
    semoss_config = load_semoss_config(SEMOSS_CONFIG_PATH)
    access_token, secret = load_bearer_parts(MCP_CONFIG_PATH)

    project_id = get_project_id(semoss_config)
    if not project_id:
        raise SystemExit("project_id was not found in semoss_config/config.json.")

    server_connection = build_server_connection(
        endpoint=build_api_endpoint(semoss_config),
        access_token=access_token,
        secret=secret,
    )
    return semoss_config, project_id, server_connection


def upload_local_file_to_semoss(
    local_file: Path,
    project_id: str,
    server_connection,
    semoss_config: dict[str, object],
) -> int:
    if not local_file.exists() or not local_file.is_file():
        raise SystemExit(f"Local file not found: {local_file}")
    if WORKSPACE_ROOT not in local_file.parents and local_file != WORKSPACE_ROOT:
        raise SystemExit("Local file must be inside the current workspace.")

    remote_directory = infer_remote_directory(local_file)
    remote_file_path = infer_remote_file_path(local_file)
    insight_id = server_connection.make_new_insight()

    remote_exists = remote_asset_exists(server_connection, project_id, remote_file_path)
    if remote_exists:
        if not confirm_remote_delete(remote_file_path):
            raise SystemExit("Upload cancelled because the existing remote asset was not approved for deletion.")

        backup_path = download_remote_asset(
            server_connection=server_connection,
            project_id=project_id,
            remote_file_path=remote_file_path,
            insight_id=f"{insight_id}",
            destination_path=build_backup_path(local_file),
        )
        print(f"Backed up remote asset to {backup_path}")

        delete_result = delete_remote_asset(server_connection, project_id, remote_file_path)
        print(f"Deleted remote asset: {remote_file_path}")
        print(json.dumps(delete_result, indent=2, default=str))

        delete_publish_result = publish_project(server_connection, project_id)
        print("Published project after deletion")
        print(json.dumps(delete_publish_result, indent=2, default=str))

        post_delete_listing = browse_remote_directory(server_connection, project_id, remote_directory)
        print_directory_state("Remote directory after deletion:", post_delete_listing)

    upload_result = server_connection.upload_files(
        files=[str(local_file)],
        project_id=project_id,
        insight_id=f"{insight_id}",
        path=remote_directory,
    )

    python_mcp_result = None
    mcp_listing: list[dict[str, object]] = []
    if should_generate_python_mcp(semoss_config):
        python_mcp_result = make_python_mcp(server_connection, project_id)
        mcp_listing = browse_remote_directory(server_connection, project_id, "version/assets/mcp")

    publish_result = publish_project(server_connection, project_id)
    final_listing = browse_remote_directory(server_connection, project_id, remote_directory)

    print(f"Uploaded {local_file}")
    print(f"Project: {project_id}")
    print(f"Insight: {insight_id}")
    print(f"Remote directory: {remote_directory}")
    print(f"Remote asset: {remote_file_path}")
    print(json.dumps(upload_result, indent=2, default=str))
    if python_mcp_result is not None:
        print("Generated SEMOSS Python MCP manifest")
        print(json.dumps(python_mcp_result, indent=2, default=str))
        print_directory_state("Remote MCP directory after generation:", mcp_listing)
    print("Published project after upload")
    print(json.dumps(publish_result, indent=2, default=str))
    print_directory_state("Remote directory after upload:", final_listing)
    return 0


def sync_semoss_folder_to_local(remote_folder: str, local_dir: str | None, overwrite: bool) -> int:
    _, project_id, server_connection = build_semoss_context()
    normalized_remote_path = normalize_remote_asset_path(remote_folder)
    target_local_dir = Path(local_dir).expanduser().resolve() if local_dir else default_local_path_for_remote(normalized_remote_path)

    result = sync_remote_folder_to_local(
        server_connection=server_connection,
        project_id=project_id,
        remote_folder_path=normalized_remote_path,
        local_folder_path=target_local_dir,
        overwrite=overwrite,
    )

    print(f"Synchronized remote folder: {normalized_remote_path}")
    print(f"Local destination: {target_local_dir}")
    print(json.dumps(result, indent=2))
    return 0


def main() -> int:
    args = parse_args()

    if args.command == "configure-local":
        summary = configure_local_semoss_files(
            access_key=args.access_key,
            secret_key=args.secret_key,
            base_url=args.base_url,
            api_module_url=args.api_module_url,
            web_module_url=args.web_module_url,
            project_id=args.project_id,
            is_mcp=args.is_mcp,
            module=args.module,
        )
        print(json.dumps(summary, indent=2, default=str))
        return 0

    if args.command == "sync-from-remote":
        return sync_semoss_folder_to_local(args.remote_folder, args.local_dir, args.overwrite)

    semoss_config, project_id, server_connection = build_semoss_context()
    local_file = Path(args.file).expanduser().resolve()
    return upload_local_file_to_semoss(local_file, project_id, server_connection, semoss_config)


if __name__ == "__main__":
    raise SystemExit(main())
