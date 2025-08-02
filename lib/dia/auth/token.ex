defmodule DIA.Auth.Token do
  use Joken.Config

  @secret System.get_env("JWT_SECRET") ||
            "I2RnY7goIbQLT7sjV8ROSJlRSU-CDX3NPyZAy-IIWrxAe9U0rgPlBIpI7pDMWSRXFdjNH91_PwohKVBLT-fcDg"

  # Helper function to compute expiration time (Unix timestamp)
  # 1 hour
  defp default_expiry_seconds(), do: 3600

  defp get_expiration_time() do
    DateTime.utc_now()
    |> DateTime.add(default_expiry_seconds())
    |> DateTime.to_unix()
  end

  # Token configuration (no chat_id)
  @impl true
  def token_config do
    default_claims(skip: [:iss, :aud])
    |> add_claim("user_id", nil, &(&1 != nil))
    |> add_claim("login_session_id", nil, &(&1 != nil))
    |> add_claim("exp", get_expiration_time(), &(&1 > DateTime.utc_now() |> DateTime.to_unix()))
  end

  def encode(claims) when is_map(claims) do
    # Ensure required fields have defaults
    enhanced_claims =
      claims
      |> Map.put_new("iat", DateTime.utc_now() |> DateTime.to_unix())

    Joken.generate_and_sign(
      token_config(),
      enhanced_claims,
      Joken.Signer.create("HS256", @secret)
    )
  end

  def decode(token),
    do: Joken.verify_and_validate(token_config(), token, Joken.Signer.create("HS256", @secret))

end
