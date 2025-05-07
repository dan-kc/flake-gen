use clap::{Parser, ValueEnum};
use fmt;
// 'dev --lang rust .'

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Cli {
    #[arg(short, long)]
    lang: Language,

    path: std::path::PathBuf,
}

#[derive(ValueEnum, Clone, Debug)]
enum Language {
    Rust,
    Go,
}
impl fmt::Display for Language {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Language::Rust => write!(f, "rust"),
            Language::Go => write!(f, "go"),
        }
    }
}

fn main() {
    // Check path exists
    // Check if flake.nix and/or .envrc already exists in specified path
    let cli = Cli::parse();

    // Create readers and writers 

    // Write to path
}
