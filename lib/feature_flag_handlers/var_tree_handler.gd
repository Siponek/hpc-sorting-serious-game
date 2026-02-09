class_name VarTreeHandler
## Handles VarTree setup and cleanup based on feature flags.
## Use this to conditionally setup or remove VarTree nodes in scenes.

## Checks if VarTree should be enabled based on feature flags.
## Requires: debug mode, editor, and var_tree feature flag
static func should_enable_var_tree() -> bool:
	return OS.has_feature("debug") and OS.has_feature("editor") and OS.has_feature("var_tree")

## Handles VarTree initialization or cleanup.
## @param node: The node that contains the VarTree (usually the scene root or a parent)
## @param var_tree_path: NodePath to the VarTree node
## @param setup_callback: Optional callable that receives the VarTree node for custom setup
## @return: The VarTree node if setup was performed, null otherwise
static func handle_var_tree(var_tree_node: VarTree, setup_callback: Callable = Callable()) -> VarTree:
	if should_enable_var_tree():
		if setup_callback.is_valid():
			setup_callback.call(var_tree_node)
		return var_tree_node
	else:
		# Remove the var tree node to save resources in release builds
		var_tree_node.queue_free()
		return null
