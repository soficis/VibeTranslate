using System;

namespace TranslationFiestaCSharp
{
    public sealed class TranslationProviderException : Exception
    {
        public string ErrorCode { get; }

        public TranslationProviderException(string errorCode, string message, Exception? innerException = null)
            : base(message, innerException)
        {
            ErrorCode = errorCode;
        }
    }
}
