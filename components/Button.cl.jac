"""Button component for the Jac client application."""

def:pub Button(
    label: str, onClick: any, variant: str = "primary", disabled: bool = False
) -> any {
    btnClass = "btn btn-primary" if variant == "primary" else "btn btn-secondary";

    return
        <button
            className={btnClass}
            onClick={onClick}
            disabled={disabled}
        >
            {label}
        </button>;
}
