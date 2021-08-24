defmodule Resolver.Incompatibility do
  alias Resolver.{PackageRange, Term}

  defstruct terms: []

  def has_package?(%__MODULE__{terms: []}, _package) do
    false
  end

  def has_package?(
        %__MODULE__{terms: [%Term{range: %PackageRange{name: package}} | _terms]},
        package
      ) do
    true
  end

  def has_package?(%__MODULE__{terms: [_term | terms]}, package) do
    has_package?(%__MODULE__{terms: terms}, package)
  end
end
