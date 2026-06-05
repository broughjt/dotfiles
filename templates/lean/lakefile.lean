import Lake
open Lake DSL

package «lean_project» where
  version := v!"0.1.0"

@[default_target]
lean_exe «lean_project» where
  root := `Main
